import itertools
import numpy as np

def candidate_pairs(triangles):
    """Median BVH, bounded leaves; avoids all-pairs for ordinary production meshes."""
    low, high = triangles.min(axis=1), triangles.max(axis=1)
    def node(indices):
        lo, hi = low[indices].min(axis=0), high[indices].max(axis=0)
        if len(indices) <= 8:
            return lo, hi, indices, None
        axis = int(np.argmax(hi - lo))
        ordered = indices[np.argsort((low[indices, axis] + high[indices, axis]), kind="stable")]
        half = len(ordered) // 2
        return lo, hi, None, (node(ordered[:half]), node(ordered[half:]))
    root = node(np.arange(len(triangles)))
    stack, count = [(root, root)], 0
    while stack:
        a, b = stack.pop()
        if np.any(a[0] > b[1] + 1e-10) or np.any(b[0] > a[1] + 1e-10):
            continue
        if a is b:
            if a[3]:
                left, right = a[3]
                stack.extend(((left, left), (left, right), (right, right)))
            else:
                yield from itertools.combinations(a[2], 2)
        elif a[3]:
            stack.extend((child, b) for child in a[3])
        elif b[3]:
            stack.extend((a, child) for child in b[3])
        else:
            for i in a[2]:
                for j in b[2]:
                    if i == j:
                        continue
                    count += 1
                    # ponytail: reject pathological ten-million-pair sources; use a compiled exact checker beyond this ceiling.
                    if count > 10000000:
                        raise ValueError("intersection complexity budget; validation incomplete")
                    yield int(i), int(j)

def overlap2(a, b):
    for tri in (a, b):
        for edge in np.roll(tri, -1, axis=0) - tri:
            axis = np.array([-edge[1], edge[0]])
            p, q = a @ axis, b @ axis
            if min(p.max(), q.max()) - max(p.min(), q.min()) <= 1e-12:
                return False
    return True

def intersect3(a, b):
    normal = np.cross(a[1] - a[0], a[2] - a[0])
    norm = np.linalg.norm(normal)
    if norm <= 1e-14:
        return False
    if np.max(np.abs((b - a[0]) @ (normal / norm))) < 1e-9:
        keep = [i for i in range(3) if i != np.argmax(np.abs(normal))]
        return overlap2(a[:, keep], b[:, keep])
    def segment(p, q, tri):
        direction = q - p
        e1, e2 = tri[1] - tri[0], tri[2] - tri[0]
        h = np.cross(direction, e2)
        det = float(e1 @ h)
        if abs(det) < 1e-14:
            return False
        s = p - tri[0]
        u = float(s @ h) / det
        v = float(direction @ np.cross(s, e1)) / det
        t = float(e2 @ np.cross(s, e1)) / det
        return 1e-9 < t < 1 - 1e-9 and u >= -1e-9 and v >= -1e-9 and u + v <= 1 + 1e-9
    return any(segment(t[i], t[(i + 1) % 3], other) for t, other in ((a, b), (b, a)) for i in range(3))
