#!/usr/bin/env python3
"""
extract_icons.py
----------------
Extracts individual 64x64 transparent icons from the raw icon sheet (icons_raw.png / icons_raw.jpg)
per Section G.2 of docs/game_system_architecture.md.

Requirements:
1. Uses rembg and Pillow.
2. Detects the 8 magenta box regions (or uses calibrated coordinates).
3. Strips the magenta background to complete transparency (Alpha=0).
4. Resizes each item to fit within a 64x64 canvas centered, preserving at least 6px safe margins.
5. Saves to assets/art/items/:
   - icon_wood.png (나무)
   - icon_stone.png (돌)
   - icon_food.png (베리)
   - icon_machine_parts.png (톱니바퀴)
   - icon_electronics.png (회로칩)
   - icon_ammo.png (선택된 탄약)
   - icon_medicine.png (약통)
"""

import os
import sys
import argparse
from pathlib import Path
from PIL import Image
import numpy as np
import rembg
import cv2


# Calibrated fixed coordinates for the 8 magenta boxes: (x, y, w, h)
FIXED_BOXES = {
    "wood": (47, 36, 234, 233),
    "stone": (317, 36, 234, 233),
    "food": (587, 36, 234, 233),
    "machine_parts": (857, 36, 234, 233),
    "electronics": (1127, 36, 234, 233),
    "ammo_rifle": (270, 398, 270, 246),
    "ammo_pistol": (587, 398, 234, 246),
    "medicine": (857, 398, 269, 246),
}


def detect_magenta_boxes(image_path: Path) -> dict:
    """
    Detects bounding boxes of the 8 magenta boxes using color thresholding and contour detection.
    Falls back to calibrated coordinates if anything fails.
    """
    img_cv = cv2.imread(str(image_path))
    if img_cv is None:
        return FIXED_BOXES
        
    b, g, r = cv2.split(img_cv)
    # Magenta threshold: High Red and Blue, Low Green
    magenta_mask = (r > 180) & (g < 80) & (b > 180)
    magenta_uint8 = (magenta_mask * 255).astype(np.uint8)
    
    contours, _ = cv2.findContours(magenta_uint8, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    detected = []
    for c in contours:
        x, y, w, h = cv2.boundingRect(c)
        if w > 120 and h > 120:
            detected.append((x, y, w, h))
            
    if len(detected) != 8:
        print(f"  [INFO] Detected {len(detected)} regions. Using calibrated coordinates.")
        return FIXED_BOXES

    top_row = sorted([b for b in detected if b[1] < 300], key=lambda b: b[0])
    bottom_row = sorted([b for b in detected if b[1] >= 300], key=lambda b: b[0])

    if len(top_row) != 5 or len(bottom_row) != 3:
        print("  [INFO] Row clustering mismatch. Using calibrated coordinates.")
        return FIXED_BOXES

    return {
        "wood": top_row[0],
        "stone": top_row[1],
        "food": top_row[2],
        "machine_parts": top_row[3],
        "electronics": top_row[4],
        "ammo_rifle": bottom_row[0],
        "ammo_pistol": bottom_row[1],
        "medicine": bottom_row[2],
    }


def remove_magenta_background(crop_img: Image.Image) -> Image.Image:
    """
    Cleans magenta background with despill to ensure full transparency and crisp edges.
    """
    rgba = crop_img.convert("RGBA")
    arr = np.array(rgba)
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    
    # 1. Pure magenta detection
    is_magenta = (
        (r > 150) & (b > 150) & (g < 120) &
        ((r.astype(int) - g.astype(int)) > 50) &
        ((b.astype(int) - g.astype(int)) > 50)
    )
    arr[is_magenta, 3] = 0
    
    # 2. Despill magenta fringe on edge pixels (soft antialiasing)
    is_fringe = (
        (r > 130) & (b > 130) & (g < 140) &
        (arr[:, :, 3] > 0)
    )
    # Neutralize magenta tint on edge pixels to dark neutral
    arr[is_fringe, 0] = (arr[is_fringe, 0].astype(int) * 3 + arr[is_fringe, 1].astype(int)) // 4
    arr[is_fringe, 2] = (arr[is_fringe, 2].astype(int) * 3 + arr[is_fringe, 1].astype(int)) // 4

    return Image.fromarray(arr)


def process_box_to_icon(sheet_img: Image.Image, box: tuple, max_dim: int = 52, canvas_size: int = 64) -> Image.Image:
    """
    Crops magenta box, strips background to Alpha=0, trims bounding box,
    scales to fit max_dim (6px safe margin in 64x64), and places centered.
    """
    x, y, w, h = box
    crop_img = sheet_img.crop((x, y, x + w, y + h))

    # Background removal
    cleaned = remove_magenta_background(crop_img)

    # Trim to visible bounding box
    bbox = cleaned.getbbox()
    if bbox is not None:
        trimmed = cleaned.crop(bbox)
    else:
        trimmed = cleaned

    tw, th = trimmed.size

    # Scale to fit inside max_dim (52x52 preserves 6px margin on 64x64)
    scale = min(float(max_dim) / float(tw), float(max_dim) / float(th))
    new_w = max(1, int(round(tw * scale)))
    new_h = max(1, int(round(th * scale)))
    resized = trimmed.resize((new_w, new_h), Image.Resampling.LANCZOS)

    # Paste centered on transparent 64x64 canvas
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    paste_x = (canvas_size - new_w) // 2
    paste_y = (canvas_size - new_h) // 2
    canvas.paste(resized, (paste_x, paste_y), resized)

    return canvas


def main():
    parser = argparse.ArgumentParser(description="Extract 64x64 transparent item icons from raw icon sheet.")
    parser.add_argument(
        "--input",
        type=str,
        default="",
        help="Path to icons_raw.png / icons_raw.jpg. Defaults to art_source/nano_banana/raw/icons_raw.png",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default="assets/art/items",
        help="Destination directory for icons (default: assets/art/items)",
    )
    parser.add_argument(
        "--ammo-choice",
        type=str,
        choices=["rifle", "pistol"],
        default="rifle",
        help="Which ammo bullet to save as icon_ammo.png: 'rifle' or 'pistol' (default: rifle)",
    )
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent.parent
    
    # Locate raw input image
    input_path = None
    if args.input:
        p = Path(args.input)
        if p.exists():
            input_path = p
        elif (project_root / args.input).exists():
            input_path = project_root / args.input

    if input_path is None:
        candidates = [
            project_root / "art_source/nano_banana/raw/icons_raw.png",
            project_root / "art_source/nano_banana/raw/icons_raw.jpg",
            project_root / "icons_raw.png",
            project_root / "icons_raw.jpg",
        ]
        for cand in candidates:
            if cand.exists():
                input_path = cand
                break

    if input_path is None or not input_path.exists():
        print("ERROR: Could not find raw icon sheet image (icons_raw.png or icons_raw.jpg)!")
        sys.exit(1)

    out_dir = (project_root / args.output_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    print("=" * 60)
    print(" EXTRACTING 64x64 ICONS FROM SHEET (Section G.2)")
    print("=" * 60)
    print(f"Input Sheet : {input_path}")
    print(f"Output Path : {out_dir}")
    print(f"Ammo Choice : {args.ammo_choice}")
    print("-" * 60)

    sheet_img = Image.open(input_path).convert("RGB")
    boxes = detect_magenta_boxes(input_path)

    items_to_process = [
        ("wood", "icon_wood.png", "Wood Logs"),
        ("stone", "icon_stone.png", "Stone Block"),
        ("food", "icon_food.png", "Berry Twig"),
        ("machine_parts", "icon_machine_parts.png", "Machine Gears"),
        ("electronics", "icon_electronics.png", "Circuit Microchip"),
        ("medicine", "icon_medicine.png", "Medicine Bottle"),
    ]

    for item_key, out_name, label in items_to_process:
        box = boxes[item_key]
        print(f"Processing {label} ({item_key})...")
        icon_img = process_box_to_icon(sheet_img, box)
        save_path = out_dir / out_name
        icon_img.save(save_path, "PNG")
        bbox = icon_img.getbbox()
        print(f"  [SAVED] {out_name} (64x64 RGBA, bbox={bbox})")

    # Ammunition processing
    ammo_key = "ammo_rifle" if args.ammo_choice == "rifle" else "ammo_pistol"
    ammo_box = boxes[ammo_key]
    print(f"Processing Ammunition ({ammo_key})...")
    ammo_icon = process_box_to_icon(sheet_img, ammo_box)
    ammo_path = out_dir / "icon_ammo.png"
    ammo_icon.save(ammo_path, "PNG")
    print(f"  [SAVED] icon_ammo.png (64x64 RGBA, selected: {args.ammo_choice}, bbox={ammo_icon.getbbox()})")

    # Save alternate ammo as separate file for flexibility
    alt_key = "ammo_pistol" if args.ammo_choice == "rifle" else "ammo_rifle"
    alt_box = boxes[alt_key]
    alt_icon = process_box_to_icon(sheet_img, alt_box)
    alt_path = out_dir / f"icon_ammo_{alt_key.replace('ammo_', '')}.png"
    alt_icon.save(alt_path, "PNG")
    print(f"  [SAVED] {alt_path.name} (64x64 RGBA, alternate bullet)")

    print("\n" + "=" * 60)
    print(" ALL ICONS EXTRACTED & SAVED SUCCESSFULLY!")
    print("=" * 60)


if __name__ == "__main__":
    main()
