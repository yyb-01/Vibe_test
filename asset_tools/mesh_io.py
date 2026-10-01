import math
import numpy as np
from .common import FILE_LIMIT, read_json

def obj(path):
    positions, normals, uv, vertices, faces, lookup = [], [], [], [], [], {}
    def index(text, rows):
        i = int(text)
        i = i - 1 if i > 0 else len(rows) + i
        if i < 0 or i >= len(rows):
            raise ValueError("OBJ index")
        return i
    for line in path.read_text(encoding="utf8").splitlines():
        words = line.split("#", 1)[0].split()
        if not words:
            continue
        if words[0] in {"v", "vn", "vt"}:
            row = list(map(float, words[1:]))
            target = positions if words[0] == "v" else normals if words[0] == "vn" else uv
            size = 2 if words[0] == "vt" else 3
            if len(row) != size or not all(map(math.isfinite, row)):
                raise ValueError("OBJ numeric shape")
            target.append(row)
        elif words[0] == "f":
            if len(words) not in {4, 5}:
                raise ValueError("OBJ final faces must be triangles/quads")
            face = []
            for word in words[1:]:
                key = tuple(word.split("/"))
                if len(key) != 3 or not all(key):
                    raise ValueError("OBJ requires UV and normal indices")
                if key not in lookup:
                    lookup[key] = len(vertices)
                    vertices.append((positions[index(key[0], positions)], normals[index(key[2], normals)], uv[index(key[1], uv)]))
                face.append(lookup[key])
            faces.append(face)
        if len(positions) > 200000 or len(faces) > 150000:
            raise ValueError("mesh budget")
    return {"positions": [v[0] for v in vertices], "normals": [v[1] for v in vertices], "uv": [v[2] for v in vertices],
            "triangles": [t for f in faces for t in ([f] if len(f) == 3 else [[f[0], f[1], f[2]], [f[0], f[2], f[3]]])], "sourceFaces": faces}

def load_mesh(path):
    if path.stat().st_size > FILE_LIMIT:
        raise ValueError("mesh file budget")
    if path.suffix.lower() == ".obj":
        mesh = obj(path)
    elif path.suffix.lower() in {".gltf", ".glb"}:
        from .gltf_io import gltf
        mesh = gltf(path)
    else:
        mesh = read_json(path)
    p, n, uv, triangles = (np.asarray(mesh[k], dtype=np.float64) for k in ("positions", "normals", "uv", "triangles"))
    if not 3 <= len(p) <= 200000 or p.shape != (len(p), 3) or n.shape != p.shape or uv.shape != (len(p), 2):
        raise ValueError("mesh attribute shape")
    if triangles.ndim != 2 or triangles.shape[1] != 3 or not 1 <= len(triangles) <= 150000:
        raise ValueError("triangle budget/shape")
    if not all(np.isfinite(a).all() for a in (p, n, uv, triangles)) or not np.equal(triangles, np.floor(triangles)).all():
        raise ValueError("non-finite vertex/normal/UV/index")
    if triangles.min() < 0 or triangles.max() >= len(p):
        raise ValueError("mesh index outside vertex array")
    mesh["triangles"] = triangles.astype(np.int64).tolist()
    return mesh
