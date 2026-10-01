import numpy as np

class Rays:
    def __init__(self, mesh):
        self.indices = np.asarray(mesh["triangles"], int)
        self.triangles = np.asarray(mesh["positions"], float)[self.indices]
        self.normals = np.asarray(mesh["normals"], float)[self.indices]
        def node(indices):
            tri = self.triangles[indices]
            lo, hi = tri.min(axis=(0, 1)), tri.max(axis=(0, 1))
            if len(indices) <= 8:
                return lo, hi, indices, None
            axis = np.argmax(hi-lo)
            ordered = indices[np.argsort(tri.mean(axis=1)[:, axis], kind="stable")]
            n = len(ordered)//2
            return lo, hi, None, (node(ordered[:n]), node(ordered[n:]))
        self.root = node(np.arange(len(self.triangles)))

    def cast(self, origin, direction, limit):
        stack, best = [self.root], None
        while stack:
            lo, hi, indices, children = stack.pop()
            lower, upper = 0.0, limit if best is None else best[0]
            valid = True
            for i in range(3):
                if abs(direction[i]) < 1e-14:
                    valid &= lo[i]-1e-10 <= origin[i] <= hi[i]+1e-10
                else:
                    a, b = sorted(((lo[i]-origin[i])/direction[i], (hi[i]-origin[i])/direction[i]))
                    lower, upper = max(lower, a), min(upper, b)
            if not valid or lower > upper:
                continue
            if children:
                stack.extend(children)
                continue
            for index in indices:
                tri = self.triangles[index]
                e1, e2 = tri[1]-tri[0], tri[2]-tri[0]
                h = np.cross(direction, e2)
                determinant = float(e1 @ h)
                if determinant <= 1e-14:  # Reject backface projection.
                    continue
                s = origin-tri[0]
                u = float(s @ h)/determinant
                v = float(direction @ np.cross(s, e1))/determinant
                t = float(e2 @ np.cross(s, e1))/determinant
                if best is not None and t > best[0]:
                    continue
                if u >= -1e-10 and v >= -1e-10 and u+v <= 1+1e-10 and -1e-10 <= t <= upper:
                    normal = np.array([1-u-v, u, v]) @ self.normals[index]
                    length = np.linalg.norm(normal)
                    if length > 1e-12:
                        best = max(0, t), normal/length
        return best
