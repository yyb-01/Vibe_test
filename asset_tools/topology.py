from collections import Counter
import numpy as np
from .geometry import candidate_pairs, intersect3, overlap2

def check_mesh(mesh, report, closed=True, deform=False, prefix="MESH"):
    p, n, uv = (np.asarray(mesh[key], dtype=float) for key in ("positions", "normals", "uv"))
    indices = np.asarray(mesh["triangles"], dtype=int)
    tri = p[indices]
    cross = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    area = np.linalg.norm(cross, axis=1) / 2
    report.check(np.all(area > 1e-12), prefix + "_ZERO_AREA")
    report.check(np.all(np.abs(np.linalg.norm(n, axis=1) - 1) <= 1e-4), prefix + "_NORMAL_LENGTH")
    report.check(np.all(np.sum(cross * n[indices].mean(axis=1), axis=1) >= -1e-10), prefix + "_NORMAL_WINDING")
    report.check(np.all((uv >= 0) & (uv <= 1)), prefix + "_UV_BOUNDS")
    lengths = np.linalg.norm(np.roll(tri, -1, axis=1) - tri, axis=2)
    for i in range(3):
        a, b, c = lengths[:, i], lengths[:, (i + 1) % 3], lengths[:, (i + 2) % 3]
        angle = np.degrees(np.arccos(np.clip((a*a + b*b - c*c) / np.maximum(2*a*b, 1e-30), -1, 1)))
        report.check(np.all(angle >= 5), prefix + "_SKINNY_ANGLE")
    report.check(np.all(lengths.max(axis=1) ** 2 / np.maximum(2 * area, 1e-30) <= 20), prefix + "_ASPECT")
    # Weld only exact canonical positions; split normals/UV remain distinct render vertices.
    _, welded = np.unique(p, axis=0, return_inverse=True)
    faces = welded[indices]
    report.check(len({tuple(sorted(f)) for f in faces}) == len(faces), prefix + "_DUPLICATE_FACE")
    edges, orientation = Counter(), Counter()
    for face in faces:
        for i in range(3):
            a, b = int(face[i]), int(face[(i + 1) % 3])
            edges[min(a, b), max(a, b)] += 1
            orientation[min(a, b), max(a, b)] += 1 if a < b else -1
    report.check(all(v <= 2 for v in edges.values()), prefix + "_NON_MANIFOLD")
    report.check(all(orientation[e] == 0 for e, count in edges.items() if count == 2), prefix + "_EDGE_WINDING")
    if closed:
        report.check(all(v == 2 for v in edges.values()), prefix + "_BOUNDARY")
        report.check(np.sum(tri[:, 0] * np.cross(tri[:, 1], tri[:, 2])) / 6 > 1e-12, prefix + "_SIGNED_VOLUME")
    else:
        allowed = {tuple(sorted(edge)) for edge in mesh.get("approvedBoundaryEdges", [])}
        report.check(all(e in allowed for e, count in edges.items() if count == 1), prefix + "_UNAPPROVED_BOUNDARY")
    self_hits = sum(1 for i, j in candidate_pairs(tri) if not set(faces[i]) & set(faces[j]) and intersect3(tri[i], tri[j]))
    report.check(self_hits == 0, prefix + "_SELF_INTERSECTION", count=self_hits)
    uv_tri = uv[indices]
    mirrored = set(mesh.get("approvedMirrorTriangles", []))
    overlaps = sum(1 for i, j in candidate_pairs(uv_tri) if not (i in mirrored and j in mirrored) and overlap2(uv_tri[i], uv_tri[j]))
    report.check(overlaps == 0, prefix + "_UV_OVERLAP", count=overlaps)
    from .gutter import check_gutter
    check_gutter(mesh, uv_tri, report, prefix)
    if deform:
        source = mesh.get("sourceFaces", [])
        report.check(bool(source) and sum(len(f) == 4 for f in source) / max(1, len(source)) >= .95 and all(3 <= len(f) <= 4 for f in source), prefix + "_DEFORM_QUADS")
        valid = all(3 <= len(f) <= 4 and all(type(i) is int and 0 <= i < len(p) for i in f) for f in source)
        report.check(valid, prefix + "_SOURCE_INDICES")
        if valid:
            triangulated = [tuple(t) for f in source for t in ([f] if len(f) == 3 else [[f[0], f[1], f[2]], [f[0], f[2], f[3]]])]
            report.check(Counter(triangulated) == Counter(map(tuple, indices)), prefix + "_SOURCE_TRIANGULATION")
        median = np.median(lengths)
        report.check(np.all((lengths >= median * .5) & (lengths <= median * 2)), prefix + "_EDGE_UNIFORMITY")
    return area, uv_tri
