#!/usr/bin/env python3
"""
process_assets.py
-----------------
Automated graphic asset preprocessor for 2D Isometric Survival Game
Based on Section G of docs/game_system_architecture.md.

Functions:
1. Strips backgrounds (fake checkerboard patterns, solid chroma-key magenta) using `rembg` and color filtering.
2. Automatically detects and slices 8-direction character turnaround sheets:
   - 1x8 horizontal strips (e.g. player_survivor)
   - 2x4 grid sheets (e.g. zombie_brute_runner)
   - 2x5 grid sheets (e.g. zombie_basic)
   - Maps to Section G.3 directions: e, se, s, sw, w, nw, n, ne
   - Saves as {stem}_{dir}_idle_00.png in assets/art/characters/
3. Crops to foreground bounding box.
4. Centers/aligns onto exact target canvas per Section G.2 (bottom-center for objects/entities, center for tiles/icons).
5. For isometric ground tiles (ground_*), enforces strict 128x64 diamond mask outside (64, 32) pivot.
6. Saves clean RGBA PNGs to appropriate assets/art/ subfolders (tiles, structures, props, characters, items).

Usage:
    pip install rembg pillow onnxruntime
    python tools/asset_pipeline/process_assets.py --force
"""

import os
import sys
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
import numpy as np

# Global cache for rembg function
_rembg_remove_fn = None

def get_rembg_remove():
    """Lazy imports rembg.remove to avoid startup overhead when not needed."""
    global _rembg_remove_fn
    if _rembg_remove_fn is not None:
        return _rembg_remove_fn
    try:
        from rembg import remove
        _rembg_remove_fn = remove
        return _rembg_remove_fn
    except Exception as e:
        print(f"  [WARN] Could not import 'rembg': {e}")
        return None


# ==============================================================================
# Specification Rules per Section G.2, G.3 & G.4
# ==============================================================================

DIRECTIONS_8 = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

SPEC_RULES = [
    # 1. Tiles (128x64, centered, diamond masked)
    {
        "prefixes": ["ground_", "tile_"],
        "size": (128, 64),
        "align": "center",
        "folder": "tiles",
        "diamond_mask": True,
    },
    # 2. 2x2 Structures (256x320, bottom-center)
    {
        "prefixes": ["base_core", "structure_core", "core_"],
        "size": (256, 320),
        "align": "bottom_center",
        "folder": "structures",
        "diamond_mask": False,
    },
    # 3. 1x1 Structures (128x192, bottom-center)
    {
        "prefixes": ["structure_", "barricade_", "turret_"],
        "size": (128, 192),
        "align": "bottom_center",
        "folder": "structures",
        "diamond_mask": False,
    },
    # 4. Large Vehicles / Large Props (256x192 or 128x192)
    {
        "prefixes": ["abandoned_car_", "car_"],
        "size": (256, 192),
        "align": "bottom_center",
        "folder": "props",
        "diamond_mask": False,
    },
    # 5. Resource Nodes & Props (128x192, bottom-center)
    {
        "prefixes": ["resource_", "prop_", "tree_", "rock_", "berry_", "vending_", "broken_", "scrap_", "loot_", "crate_"],
        "size": (128, 192),
        "align": "bottom_center",
        "folder": "props",
        "diamond_mask": False,
    },
    # 6. Large Entities (192x192, bottom-center)
    {
        "prefixes": ["zombie_brute", "zombie_runner", "zombie_large"],
        "size": (192, 192),
        "align": "bottom_center",
        "folder": "characters",
        "diamond_mask": False,
    },
    # 7. Standard Entities (128x128, bottom-center)
    {
        "prefixes": ["player_", "zombie_", "character_", "enemy_"],
        "size": (128, 128),
        "align": "bottom_center",
        "folder": "characters",
        "diamond_mask": False,
    },
    # 8. Icons / Items (64x64, center with 6px safe margin -> max 52x52)
    {
        "prefixes": ["icon_", "item_"],
        "size": (64, 64),
        "align": "center_icon",
        "folder": "items",
        "diamond_mask": False,
    },
    # 9. VFX Frames (128x128, center)
    {
        "prefixes": ["vfx_", "fx_"],
        "size": (128, 128),
        "align": "center",
        "folder": "vfx",
        "diamond_mask": False,
    },
]

DEFAULT_RULE = {
    "size": (128, 192),
    "align": "bottom_center",
    "folder": "props",
    "diamond_mask": False,
}


def get_rule_for_filename(filename: str) -> dict:
    stem = Path(filename).stem.lower()
    for rule in SPEC_RULES:
        for prefix in rule["prefixes"]:
            if stem.startswith(prefix):
                return rule
    return DEFAULT_RULE


def detect_character_sheet_type(stem: str, img: Image.Image) -> str:
    """
    Identifies character turnaround sheet layout:
    - '1x8': single horizontal row of 8 figures (e.g. player_survivor)
    - '2x4': 2 rows of 4 figures (e.g. zombie_brute_runner)
    - '2x5': 2 rows of 5 figures (e.g. zombie_basic)
    - 'none': single entity sprite
    """
    stem_lower = stem.lower()
    is_char = any(stem_lower.startswith(p) for p in ["player_", "zombie_", "character_"])
    if not is_char:
        return "none"

    w, h = img.size
    ratio = w / max(1, h)

    if "brute" in stem_lower or "runner" in stem_lower:
        return "2x4"
    if "zombie_basic" in stem_lower:
        return "2x5"
    if ratio >= 1.5:
        return "1x8"

    return "none"


def create_diamond_mask(width: int = 128, height: int = 64) -> Image.Image:
    """
    Creates a 1-channel 8-bit mask (255 inside diamond, 0 outside).
    2:1 isometric diamond centered at (64, 32):
    Top: (64, 0), Right: (127, 31), Bottom: (64, 63), Left: (0, 31).
    """
    mask = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask)
    diamond_polygon = [
        (width // 2, 0),
        (width - 1, (height // 2) - 1),
        (width // 2, height - 1),
        (0, (height // 2) - 1),
    ]
    draw.polygon(diamond_polygon, fill=255)
    return mask


def apply_diamond_mask(image: Image.Image) -> Image.Image:
    """Applies a strict 128x64 diamond mask, setting all pixels outside the diamond to Alpha 0."""
    if image.size != (128, 64):
        image = image.resize((128, 64), Image.Resampling.LANCZOS)

    mask = create_diamond_mask(128, 64)
    r, g, b, a = image.split()
    new_a = ImageChops.multiply(a, mask)
    image.putalpha(new_a)
    return image


def remove_magenta_background(image: Image.Image) -> Image.Image:
    """
    Cleans solid magenta chroma-key background with fringe despill.
    Leaves non-magenta pixels completely untouched.
    """
    rgba = image.convert("RGBA")
    arr = np.array(rgba)
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]

    is_magenta = (
        (r > 150) & (b > 150) & (g < 120) &
        ((r.astype(int) - g.astype(int)) > 50) &
        ((b.astype(int) - g.astype(int)) > 50)
    )

    if np.any(is_magenta):
        arr[is_magenta, 3] = 0
        # Despill magenta fringe on edge pixels
        is_fringe = (r > 130) & (b > 130) & (g < 140) & (arr[:, :, 3] > 0)
        arr[is_fringe, 0] = (arr[is_fringe, 0].astype(int) * 3 + arr[is_fringe, 1].astype(int)) // 4
        arr[is_fringe, 2] = (arr[is_fringe, 2].astype(int) * 3 + arr[is_fringe, 1].astype(int)) // 4
        return Image.fromarray(arr)

    return rgba


def remove_background(image: Image.Image) -> Image.Image:
    """
    Removes background using both color despill and rembg (u2net) to eliminate
    fake checkerboards, matte borders, and chroma-key backdrops.
    """
    image = remove_magenta_background(image)

    rembg_fn = get_rembg_remove()
    if rembg_fn is None:
        return image.convert("RGBA")

    try:
        no_bg = rembg_fn(image)
        return no_bg
    except Exception as e:
        print(f"  [ERROR] rembg failed: {e}. Keeping current image.")
        return image.convert("RGBA")


def process_turnaround_sheet(
    sheet_img: Image.Image,
    src_path: Path,
    output_base_dir: Path,
    sheet_type: str,
    skip_rembg: bool = False,
    force: bool = False,
) -> bool:
    """
    Processes an 8-direction character turnaround strip/sheet:
    - Slices frames based on sheet_type ('1x8', '2x4', '2x5').
    - Maps each to [e, se, s, sw, w, nw, n, ne].
    - Applies background removal, bottom-center alignment, and 128x128 (or 192x192) canvas.
    - Saves as {stem}_{dir}_idle_00.png in assets/art/characters/.
    """
    stem = src_path.stem
    target_dir = output_base_dir / "characters"
    target_dir.mkdir(parents=True, exist_ok=True)

    is_large = any(stem.lower().startswith(p) for p in ["zombie_brute", "zombie_runner", "zombie_large"])
    cw, ch = (192, 192) if is_large else (128, 128)

    total_w, total_h = sheet_img.size
    print(f"\n[8-DIR SHEET DETECTED: {sheet_type}] {src_path.name} ({total_w}x{total_h})")
    print(f"  Target: 8 slices ({', '.join(DIRECTIONS_8)}) -> {cw}x{ch} Bottom-Center -> {target_dir.name}/")

    # Generate coordinate crops for each direction
    crops = {}
    if sheet_type == "1x8":
        slice_w = total_w / 8.0
        for i, d in enumerate(DIRECTIONS_8):
            x1 = int(round(i * slice_w))
            x2 = int(round((i + 1) * slice_w)) if i < 7 else total_w
            crops[d] = (x1, 0, x2, total_h)
    elif sheet_type == "2x4":
        col_w = total_w / 4.0
        row_h = total_h / 2.0
        for i, d in enumerate(DIRECTIONS_8):
            row = i // 4
            col = i % 4
            x1 = int(round(col * col_w))
            y1 = int(round(row * row_h))
            x2 = int(round((col + 1) * col_w)) if col < 3 else total_w
            y2 = int(round((row + 1) * row_h)) if row < 1 else total_h
            crops[d] = (x1, y1, x2, y2)
    elif sheet_type == "2x5":
        col_w = total_w / 5.0
        row_h = total_h / 2.0
        mapping = {
            "e": (1, 4),
            "se": (0, 1),
            "s": (0, 2),
            "sw": (0, 3),
            "w": (1, 0),
            "nw": (1, 1),
            "n": (1, 2),
            "ne": (1, 3),
        }
        for d, (row, col) in mapping.items():
            x1 = int(round(col * col_w))
            y1 = int(round(row * row_h))
            x2 = int(round((col + 1) * col_w)) if col < 4 else total_w
            y2 = int(round((row + 1) * row_h)) if row < 1 else total_h
            crops[d] = (x1, y1, x2, y2)

    all_success = True
    for dir_code in DIRECTIONS_8:
        out_filename = f"{stem}_{dir_code}_idle_00.png"
        out_path = target_dir / out_filename

        if out_path.exists() and not force:
            print(f"  [SKIP] {out_filename} already exists. Use --force to overwrite.")
            continue

        box = crops[dir_code]
        slice_img = sheet_img.crop(box)

        # 1. Background removal
        if not skip_rembg:
            slice_img = remove_background(slice_img)
        else:
            slice_img = remove_magenta_background(slice_img)

        # 2. Trim visible bounding box
        bbox = slice_img.getbbox()
        if bbox is not None:
            trimmed = slice_img.crop(bbox)
        else:
            print(f"  [WARN] Slice '{dir_code}' is completely transparent!")
            trimmed = slice_img

        tw, th = trimmed.size

        # 3. Scale down preserving aspect ratio if larger than target canvas
        # Leave a 2px padding at top so character head doesn't touch extreme canvas border
        target_max_h = ch - 4
        target_max_w = cw - 8
        scale = min(float(target_max_w) / float(tw), float(target_max_h) / float(th), 1.0)
        new_w = max(1, int(round(tw * scale)))
        new_h = max(1, int(round(th * scale)))
        trimmed = trimmed.resize((new_w, new_h), Image.Resampling.LANCZOS)

        # 4. Canvas creation and Bottom-Center alignment (feet on baseline)
        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        paste_x = (cw - new_w) // 2
        paste_y = ch - new_h  # Foot/ground contact at exact bottom
        canvas.paste(trimmed, (paste_x, paste_y), trimmed)

        # 5. Save output as PNG
        try:
            canvas.save(out_path, "PNG")
            print(f"  [SAVED] {out_filename} ({cw}x{ch} RGBA, direction: {dir_code})")
        except Exception as e:
            print(f"  [FAIL] Could not save {out_path}: {e}")
            all_success = False

    return all_success


def process_image(src_path: Path, output_base_dir: Path, skip_rembg: bool = False, force: bool = False) -> bool:
    """Processes a single raw image file (turnaround sheet or standard asset)."""
    try:
        with Image.open(src_path) as raw_img:
            img = raw_img.convert("RGBA")
    except Exception as e:
        print(f"  [FAIL] Could not open {src_path}: {e}")
        return False

    # Check for character turnaround sheet
    sheet_type = detect_character_sheet_type(src_path.stem, img)
    if sheet_type != "none":
        return process_turnaround_sheet(img, src_path, output_base_dir, sheet_type=sheet_type, skip_rembg=skip_rembg, force=force)

    # Standard single asset processing
    out_filename = f"{src_path.stem}.png"
    rule = get_rule_for_filename(src_path.stem)
    target_dir = output_base_dir / rule["folder"]
    target_dir.mkdir(parents=True, exist_ok=True)
    out_path = target_dir / out_filename

    if out_path.exists() and not force:
        print(f"  [SKIP] {out_filename} already exists at {out_path.relative_to(output_base_dir.parent)}. Use --force to overwrite.")
        return True

    print(f"\nProcessing: {src_path.name} -> {rule['folder']}/{out_filename}")
    print(f"  Target Canvas: {rule['size'][0]}x{rule['size'][1]} | Align: {rule['align']}")

    # 1. Background removal
    if not skip_rembg:
        img = remove_background(img)
    else:
        img = remove_magenta_background(img)

    # 2. Trim bounding box of visible content
    bbox = img.getbbox()
    if bbox is None:
        print("  [WARN] Image is completely transparent after background removal!")
        trimmed = img
    else:
        trimmed = img.crop(bbox)

    tw, th = trimmed.size
    cw, ch = rule["size"]

    # 3. Scaling to fit target canvas
    if rule["align"] == "center_icon":
        max_icon_dim = 52
        scale = min(float(max_icon_dim) / float(tw), float(max_icon_dim) / float(th), 1.0)
        new_w = max(1, int(round(tw * scale)))
        new_h = max(1, int(round(th * scale)))
        trimmed = trimmed.resize((new_w, new_h), Image.Resampling.LANCZOS)
    elif rule.get("diamond_mask", False):
        trimmed = trimmed.resize((cw, ch), Image.Resampling.LANCZOS)
    else:
        if tw > cw or th > ch:
            scale = min(float(cw) / float(tw), float(ch) / float(th))
            new_w = max(1, int(round(tw * scale)))
            new_h = max(1, int(round(th * scale)))
            trimmed = trimmed.resize((new_w, new_h), Image.Resampling.LANCZOS)

    # 4. Canvas creation and placement
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    paste_w, paste_h = trimmed.size

    if rule["align"] == "bottom_center":
        paste_x = (cw - paste_w) // 2
        paste_y = ch - paste_h
    else:
        paste_x = (cw - paste_w) // 2
        paste_y = (ch - paste_h) // 2

    canvas.paste(trimmed, (paste_x, paste_y), trimmed)

    # 5. Apply diamond mask if tile
    if rule.get("diamond_mask", False):
        canvas = apply_diamond_mask(canvas)
        print("  [APPLIED] 128x64 Diamond Mask (Alpha 0 outside diamond)")

    # 6. Save output as PNG
    try:
        canvas.save(out_path, "PNG")
        print(f"  [SAVED] {out_path.name} ({cw}x{ch} RGBA)")
        return True
    except Exception as e:
        print(f"  [FAIL] Could not save {out_path}: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Preprocess raw Nano Banana art assets: background removal, 8-dir turnaround sheet slicing, canvas fitting, and diamond masking."
    )
    parser.add_argument(
        "--input-dir",
        type=str,
        default="art_source/nano_banana/raw",
        help="Path to folder containing raw PNG/JPG images (default: art_source/nano_banana/raw)",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default="assets/art",
        help="Path to game assets art directory (default: assets/art)",
    )
    parser.add_argument(
        "--skip-rembg",
        action="store_true",
        help="Skip AI background removal and only perform slicing, canvas scaling, and masking",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing output assets",
    )
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent.parent
    input_dir = (project_root / args.input_dir).resolve()
    output_dir = (project_root / args.output_dir).resolve()

    print("=" * 60)
    print(" NANO BANANA ASSET PREPROCESSING PIPELINE")
    print("=" * 60)
    print(f"Input Directory : {input_dir}")
    print(f"Output Directory: {output_dir}")
    print(f"Force Overwrite : {args.force}")
    print("-" * 60)

    if not input_dir.exists():
        print(f"Input directory does not exist: {input_dir}")
        sys.exit(1)

    raw_files = []
    for ext in ["*.png", "*.jpg", "*.jpeg", "*.webp"]:
        raw_files.extend(list(input_dir.glob(f"**/{ext}")))

    # Exclude icons_raw (handled by extract_icons.py)
    raw_files = sorted([f for f in raw_files if "icons_raw" not in f.stem.lower()])

    if not raw_files:
        print(f"No image files found in {input_dir}.")
        print("Place raw generated images into art_source/nano_banana/raw/ and run again.")
        sys.exit(0)

    print(f"Found {len(raw_files)} image files to process.\n")

    success_count = 0
    fail_count = 0

    for file_path in raw_files:
        if process_image(file_path, output_dir, skip_rembg=args.skip_rembg, force=args.force):
            success_count += 1
        else:
            fail_count += 1

    print("\n" + "=" * 60)
    print(f" COMPLETED: {success_count} succeeded, {fail_count} failed")
    print("=" * 60)


if __name__ == "__main__":
    main()
