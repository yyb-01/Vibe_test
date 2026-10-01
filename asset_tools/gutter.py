import numpy as np
from .geometry import candidate_pairs

def check_gutter(mesh, triangles, report, prefix):
    parents, edges = list(range(len(triangles))), {}
    def root(i):
        while parents[i] != i:
            parents[i] = parents[parents[i]]
            i = parents[i]
        return i
    for i, tri in enumerate(triangles):
        for j in range(3):
            key = tuple(sorted((tuple(tri[j]), tuple(tri[(j+1)%3]))))
            if key in edges:
                parents[root(i)] = root(edges[key])
            else:
                edges[key] = i
    island = [root(i) for i in range(len(triangles))]
    padding, violations = 16/2048, 0
    boxes = np.stack((triangles.min(axis=1)-padding, triangles.max(axis=1)+padding, triangles.min(axis=1)-padding), axis=1)
    mirrors = set(mesh.get("approvedMirrorTriangles", []))
    def distance(points, tri):
        result = float("inf")
        for i in range(3):
            begin, end = tri[i], tri[(i+1)%3]
            delta = end-begin
            t = np.clip((points-begin) @ delta/max(1e-30, delta @ delta), 0, 1)
            result = min(result, float(np.linalg.norm(points-begin-t[:, None]*delta, axis=1).min()))
        return result
    for i, j in candidate_pairs(boxes):
        if island[i] == island[j] or (i in mirrors and j in mirrors):
            continue
        if min(distance(triangles[i], triangles[j]), distance(triangles[j], triangles[i])) < padding-1e-10:
            violations += 1
    report.check(violations == 0, prefix + "_MEASURED_UV_GUTTER", count=violations, minimumAt2K=16)
