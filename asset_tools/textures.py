import numpy as np
from PIL import Image
from .common import digest, local_file

Image.MAX_IMAGE_PIXELS = 16777216

def textures(manifest, style, root, report):
    rows, arrays = manifest.get("textures", {}), {}
    for kind, row in rows.items():
        file = local_file(root, row["file"])
        if file.suffix.lower() != ".png":
            raise ValueError("source texture must be lossless PNG")
        with Image.open(file) as image:
            if image.width > 4096 or image.height > 4096 or image.width * image.height > 16777216:
                raise ValueError("texture budget")
            arrays[kind] = np.asarray(image.convert("RGBA"))
        report.value["artifactHashes"][row["file"]] = digest(file.read_bytes())
        report.check(row.get("sRGB") is (kind == "baseColor"), kind.upper() + "_COLORSPACE")
        a = arrays[kind]
        limit = style["classes"][manifest["assetClass"]]["textureMax"]
        report.check(a.shape[0] <= limit and a.shape[1] <= limit, "TEXTURE_CLASS_BUDGET")
    report.check(all(k in arrays for k in ("baseColor", "normal", "orm", "id")), "TEXTURE_CHANNELS")
    if not all(k in arrays for k in ("baseColor", "normal", "orm", "id")):
        return arrays
    shape = arrays["baseColor"].shape
    report.check(all(a.shape == shape for a in arrays.values()), "TEXTURE_DIMENSIONS")
    if not all(a.shape == shape for a in arrays.values()):
        return arrays
    bc, orm, ids = arrays["baseColor"], arrays["orm"], arrays["id"][..., 0]
    valid = bc[..., 3] > 0
    rgb = bc[..., :3][valid]
    if not len(rgb):
        raise ValueError("empty opaque coverage")
    outside = np.any((rgb < 30) | (rgb > 240), axis=1)
    report.check(not outside.any(), "ALBEDO_FINAL_RANGE")
    report.value["metrics"]["albedoOutOfRangeFraction"] = float(outside.mean())
    maximum, minimum = rgb.max(axis=1).astype(float), rgb.min(axis=1).astype(float)
    saturation = (maximum - minimum) / np.maximum(maximum, 1)
    report.check(np.median(saturation) <= .45 and np.percentile(saturation, 99) <= .70, "STYLE_SATURATION")
    report.check(np.all(orm[..., 3] == 255), "ORM_ALPHA")
    report.check(rows["id"].get("filter") == "nearest", "CATEGORICAL_FILTER")
    report.check(manifest.get("normalConvention") == "DirectX_Yminus_MikkTSpace", "NORMAL_CONVENTION")
    normal = arrays["normal"][..., :2].astype(float) / 127.5 - 1
    report.check(np.all(np.sum(normal * normal, axis=-1) <= 1.02), "NORMAL_HEMISPHERE")
    materials = manifest["materials"]
    report.check(np.all(ids <= len(materials)), "SEMANTIC_MATERIAL_ID")
    for i, material in enumerate(materials, 1):
        profile = style["materials"][material]
        mask = (ids == i) & valid
        report.check(np.all(orm[..., 2][mask] == profile["metallic"] * 255), "SOURCE_METALLIC", material=material)
        roughness = orm[..., 1][mask] / 255
        report.check(np.all((roughness >= profile["roughness"][0]) & (roughness <= profile["roughness"][1])), "ROUGHNESS_PROFILE", material=material)
        if np.any(mask):
            from .color import lab, delta_e
            difference = delta_e(lab(bc[..., :3][mask]), lab(profile["baseColor"]))
            median, p95 = float(np.median(difference)), float(np.percentile(difference, 95))
            report.check(median <= 3 and p95 <= 6, "SEMANTIC_COLOR_DELTA_E00", material=material, median=median, p95=p95)
    report.value["metrics"]["textureMipBytes"] = sum(a.shape[0] * a.shape[1] * 4 // 3 for k, a in arrays.items() if k in {"baseColor", "normal", "orm"})
    return arrays
