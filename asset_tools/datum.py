import math
import numpy as np

def datum(manifest, mesh, template, report):
    sockets = manifest.get("sockets", [])
    expected = {s["id"]: s for s in template["sockets"]}
    report.check(len(sockets) == len(expected) and len({s["id"] for s in sockets}) == len(sockets), "SOCKET_SET")
    for socket in sockets:
        if socket["id"] not in expected:
            report.check(False, "SOCKET_UNKNOWN")
            continue
        target = expected[socket["id"]]
        q, reference = np.asarray(socket["rotationXYZW"], float), np.asarray(target["rotationXYZW"], float)
        position = np.asarray(socket["positionNm"])
        report.check(position.shape == (3,) and np.equal(position, np.floor(position)).all(), "SOCKET_INTEGER_NM")
        report.check(q.shape == (4,) and np.isfinite(q).all() and abs(np.linalg.norm(q) - 1) <= 1e-10, "SOCKET_ROTATION")
        if position.shape != (3,) or q.shape != (4,):
            continue
        angle = 2 * math.acos(min(1, abs(float(q @ reference))))
        error = np.linalg.norm(position - np.asarray(target["positionNm"])) / 1e9 + 2 * template["radiusM"] * math.sin(angle / 2)
        report.check(error <= 1e-6, "SOCKET_DATUM", measuredM=float(error), limitM=1e-6)
        report.check(all(socket.get(k) == target[k] for k in ("profileId", "gender", "keyVariant")), "SOCKET_PROFILE")
    points = np.asarray(mesh["positions"], float)
    landmarks = mesh.get("landmarks", {})
    for label, target in template["landmarks"].items():
        if label not in landmarks:
            report.check(False, "INTERFACE_LANDMARK", label=label)
        else:
            index = landmarks[label]
            if not isinstance(index, int) or not 0 <= index < len(points):
                report.check(False, "LANDMARK_INDEX", label=label)
            else:
                distance = float(np.linalg.norm(points[index] - target))
                report.check(distance <= 1e-6, "INTERFACE_LANDMARK", label=label, measuredM=distance)

def register(mesh, source, template):
    labels = sorted(template["landmarks"])
    points = np.asarray(mesh["positions"], float)
    origins = np.asarray([points[source[k]] for k in labels])
    targets = np.asarray([template["landmarks"][k] for k in labels], float)
    if len(labels) < 3 or np.linalg.matrix_rank(origins - origins.mean(axis=0), tol=1e-10) < 2:
        raise ValueError("three non-collinear labelled landmarks are required")
    ratios = [np.linalg.norm(targets[i]-targets[j])/np.linalg.norm(origins[i]-origins[j])
              for i in range(len(labels)) for j in range(i) if np.linalg.norm(origins[i]-origins[j]) > 1e-10]
    scale = float(np.median(ratios))
    if not all(abs(r / scale - 1) <= .005 for r in ratios):
        raise ValueError("nonuniform dimension error exceeds 0.5%; regenerate source")
    origins *= scale
    a, b = origins.mean(axis=0), targets.mean(axis=0)
    u, _, v = np.linalg.svd((origins-a).T @ (targets-b))
    flip = np.eye(3)
    flip[2, 2] = np.linalg.det(v.T @ u.T)
    rotation = v.T @ flip @ u.T
    transformed = (points * scale-a) @ rotation.T+b
    residual = np.linalg.norm(transformed[[source[k] for k in labels]]-targets, axis=1).max()
    if residual > 1e-6:
        raise ValueError("rigid registration residual exceeds 1 micrometre")
    mesh["positions"] = transformed.tolist()
    mesh["normals"] = (np.asarray(mesh["normals"]) @ rotation.T).tolist()
    for label, target in template["landmarks"].items():
        mesh["positions"][source[label]] = target
    mesh["landmarks"] = source
    return scale, float(residual)
