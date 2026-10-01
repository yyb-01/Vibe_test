"""Pinned Microsoft DirectXTex CPU encoder; no GPU or renderer dependency."""
import struct
import subprocess
from pathlib import Path
import numpy as np
from PIL import Image
from .common import digest, local_file
from .color import delta_e, lab

TOOL_HASH = "dcfdec10244e02cf5037fba089c55fb7e1326b1c8181742d77d15fa5cb5eef06"

def dds_info(path):
    data = Path(path).read_bytes()
    if len(data) < 148 or data[:4] != b"DDS " or data[84:88] != b"DX10":
        raise ValueError("DDS DX10 header")
    size, _, height, width = struct.unpack_from("<4I", data, 4)
    mips, = struct.unpack_from("<I", data, 28)
    fmt, dimension, _, count, _ = struct.unpack_from("<5I", data, 128)
    if size != 124 or fmt not in {83, 98, 99} or dimension != 3 or count != 1 or not 4 <= width <= 4096 or not 4 <= height <= 4096 or mips != max(width, height).bit_length():
        raise ValueError("DDS format/dimensions/mipchain")
    expected = 148 + sum(((max(1, width >> i)+3)//4)*((max(1, height >> i)+3)//4)*16 for i in range(mips))
    if len(data) != expected:
        raise ValueError("DDS mip data bounds")
    return {"format": fmt, "width": width, "height": height, "mips": mips, "bytes": len(data)}

def compress_textures(manifest, root, package):
    tool = Path(__file__).resolve().parents[1] / ".tools/directxtex/texconv.exe"
    if not tool.exists() or digest(tool.read_bytes()) != TOOL_HASH:
        raise ValueError("run scripts/setup-asset-tools.ps1; pinned texconv missing")
    output = package / "textures"; output.mkdir()
    evidence = {}
    for kind, fmt, code in (("baseColor", "BC7_UNORM_SRGB", 99), ("normal", "BC5_UNORM", 83), ("orm", "BC7_UNORM", 98)):
        source = local_file(root, manifest["textures"][kind]["file"])
        target = output / (kind+".dds")
        result = subprocess.run([str(tool), "-nologo", "-nogpu", "--single-proc", "-dx10", "-f", fmt, "-m", "0", "-srgb" if kind == "baseColor" else "--ignore-srgb", "-o", str(output), str(source)], capture_output=True, timeout=300)
        if result.returncode:
            raise ValueError("texconv compression failed")
        generated = output / (source.stem+".dds")
        if generated != target: generated.rename(target)
        info = dds_info(target)
        if info["format"] != code: raise ValueError("DDS colorspace")
        with Image.open(source) as im: original = np.asarray(im.convert("RGB"))
        with Image.open(target) as im: actual = np.asarray(im.convert("RGB"))
        if kind == "baseColor":
            error = delta_e(lab(original), lab(actual)); threshold = 6
        elif kind == "normal":
            def normal(image):
                xy = image[..., :2].astype(float)/127.5-1
                n = np.dstack((xy, np.sqrt(np.maximum(0, 1-(xy*xy).sum(axis=2)))))
                return n/np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-12)
            error = np.degrees(np.arccos(np.clip((normal(original)*normal(actual)).sum(axis=2), -1, 1))); threshold = 8
        else:
            error = np.abs(original.astype(float)-actual)/255; threshold = .04
        p99 = float(np.percentile(error, 99))
        if p99 > threshold: raise ValueError("compressed texture error: "+kind)
        evidence[kind] = {"file": target.relative_to(package).as_posix(), **info, "p99Error": p99, "encoderHash": TOOL_HASH}
    return evidence
