import struct
import subprocess
import tempfile
from pathlib import Path
import numpy as np
from PIL import Image
from game_launcher.common import ROOT
from .common import canonical, digest, local_file, read_json
from .rays import Rays

MIKK_COMMIT = "3e895b49d05ea07e4c2133156cfa94369e19e409"

def tangents(mesh):
    faces = np.asarray(mesh["triangles"], int)
    values = np.concatenate([np.asarray(mesh[k], dtype=np.float32)[faces] for k in ("positions", "normals", "uv")], axis=2)
    data = struct.pack("<II", 0x4b4b494d, len(faces)) + values.astype("<f4").tobytes()
    result = subprocess.run([str(ROOT / ".build/astra-mikk.exe")], input=data, capture_output=True, check=True, timeout=120).stdout
    if len(result) != 8 + len(faces)*3*16 or struct.unpack_from("<II", result) != (0x544b494d, len(faces)):
        raise ValueError("MikkTSpace output shape")
    return np.frombuffer(result, dtype="<f4", offset=8).reshape((-1, 3, 4)).copy()

def bake_normal(low, high, output, size=512, cage=.01):
    if not 8 <= size <= 4096 or not 0 < cage <= 1:
        raise ValueError("bake size/cage")
    tangent, rays = tangents(low), Rays(high)
    indices = np.asarray(low["triangles"], int)
    p, n, uv = (np.asarray(low[k], float)[indices] for k in ("positions", "normals", "uv"))
    image = np.full((size, size, 3), [128, 128, 255], dtype=np.uint8)
    coverage, misses, interface_miss = np.zeros((size, size), bool), 0, 0
    interface = set(low.get("landmarks", {}).values())
    for index, triangle in enumerate(uv):
        matrix = np.column_stack((triangle[1]-triangle[0], triangle[2]-triangle[0]))
        if abs(np.linalg.det(matrix)) < 1e-14:
            raise ValueError("degenerate bake UV")
        inverse = np.linalg.inv(matrix)
        begin = np.maximum(0, np.floor(triangle.min(axis=0)*size).astype(int))
        end = np.minimum(size-1, np.ceil(triangle.max(axis=0)*size).astype(int))
        for y in range(begin[1], end[1]+1):
            for x in range(begin[0], end[0]+1):
                a, b = inverse @ ((np.array([x+.5, y+.5])/size)-triangle[0])
                weights = np.array([1-a-b, a, b])
                if weights.min() < -1e-10:
                    continue
                coverage[y, x] = True
                position, normal = weights @ p[index], weights @ n[index]
                normal /= np.linalg.norm(normal)
                hit = rays.cast(position+normal*cage, -normal, 2*cage)
                if hit is None:
                    misses += 1
                    interface_miss += bool(interface & set(indices[index]))
                    continue
                t = weights @ tangent[index, :, :3]
                t -= normal * (t @ normal)
                t /= np.linalg.norm(t)
                sign = 1 if weights @ tangent[index, :, 3] >= 0 else -1
                bitangent = np.cross(normal, t)*sign
                encoded = np.array([hit[1] @ t, -(hit[1] @ bitangent), hit[1] @ normal])
                image[y, x] = np.clip(np.rint((encoded+1)*127.5), 0, 255)
    pixels = int(coverage.sum())
    if not pixels:
        raise ValueError("empty bake coverage")
    # Dilate only into padding; source texels and fixed triangulation are preserved.
    filled = coverage.copy()
    for _ in range(max(1, int(np.ceil(size*8/2048)))):
        prior = filled.copy()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            source_y, source_x = slice(max(0, -dy), size-max(0, dy)), slice(max(0, -dx), size-max(0, dx))
            target_y, target_x = slice(max(0, dy), size-max(0, -dy)), slice(max(0, dx), size-max(0, -dx))
            mask = prior[source_y, source_x] & ~filled[target_y, target_x]
            image[target_y, target_x][mask] = image[source_y, source_x][mask]
            filled[target_y, target_x][mask] = True
    Image.fromarray(np.flipud(image)).save(output)
    return {"mikkCommit": MIKK_COMMIT, "size": size, "lowHash": digest(canonical(low)), "highHash": digest(canonical(high)),
            "tangentHash": digest(tangent.tobytes()), "normalHash": digest(Path(output).read_bytes()),
            "rayMissFraction": misses/pixels, "interfaceMissCount": interface_miss, "cageM": cage,
            "normalConvention": "DirectX_Yminus_MikkTSpace", "triangulationHash": digest(canonical(low["triangles"]))}

def verify_bake(manifest, root, report):
    from .mesh_io import load_mesh
    row = manifest["bake"]
    file = local_file(root, row["report"])
    evidence = read_json(file)
    low = load_mesh(local_file(root, manifest["lods"][0]["mesh"]))
    high_file = local_file(root, row["high"])
    high = load_mesh(high_file)
    normal_file = local_file(root, manifest["textures"]["normal"]["file"])
    report.check(evidence.get("mikkCommit") == MIKK_COMMIT, "MIKK_VERSION")
    report.check(evidence.get("lowHash") == digest(canonical(low)) and evidence.get("highHash") == digest(canonical(high)) and evidence.get("triangulationHash") == digest(canonical(low["triangles"])), "BAKE_INPUT_HASHES")
    report.check(evidence.get("tangentHash") == digest(tangents(low).tobytes()) and evidence.get("normalHash") == digest(normal_file.read_bytes()), "BAKE_OUTPUT_HASHES")
    report.check(0 <= evidence.get("rayMissFraction", 1) < .001 and evidence.get("interfaceMissCount", 1) == 0, "BAKE_RAY_MISS")
    with tempfile.TemporaryDirectory() as directory:
        recomputed = bake_normal(low, high, Path(directory) / "normal.png", evidence["size"], evidence["cageM"])
    report.check(recomputed == evidence, "BAKE_RECOMPUTED_EVIDENCE")
    reference = np.asarray(Image.open(local_file(root, row["reference"])).convert("RGB"), float)/127.5-1
    actual = np.asarray(Image.open(normal_file).convert("RGB"), float)/127.5-1
    if actual.shape != reference.shape:
        raise ValueError("normal reference shape")
    dot = np.sum(actual*reference, axis=2)/np.maximum(1e-12, np.linalg.norm(actual, axis=2)*np.linalg.norm(reference, axis=2))
    angles = np.degrees(np.arccos(np.clip(dot, -1, 1)))
    report.check(angles.mean() <= 2 and np.percentile(angles, 99) <= 8, "NORMAL_REFERENCE_ANGLE")
    for key in (row["report"], row["high"], row["reference"]):
        report.value["artifactHashes"][key] = digest(local_file(root, key).read_bytes())
