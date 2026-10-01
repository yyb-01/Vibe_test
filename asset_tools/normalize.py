import copy
from pathlib import Path
import numpy as np
from .common import canonical, digest, read_json
from .datum import register
from .mesh_io import load_mesh

def normalize(source, metadata_path, style_path, template_id, output):
    source, output = Path(source), Path(output)
    if source.resolve() == output.resolve() or output.exists():
        raise ValueError("normalization preserves sources and refuses overwrite")
    mesh, metadata, style = load_mesh(source), read_json(metadata_path), read_json(style_path)
    mesh = copy.deepcopy(mesh)
    units = {"metre": 1, "centimetre": .01, "millimetre": .001}
    if metadata["units"] not in units or metadata["basis"] not in {
        "RH_Xforward_Yleft_Zup", "LH_Xforward_Yright_Zup"}:
        raise ValueError("explicit source unit/basis required")
    matrix = np.asarray(metadata.get("transform", np.eye(4)), float)
    if matrix.shape != (4, 4) or not np.isfinite(matrix).all() or not np.array_equal(matrix[3], [0, 0, 0, 1]):
        raise ValueError("invalid source transform")
    basis = np.diag([1, -1, 1]) if metadata["basis"].startswith("LH") else np.eye(3)
    linear = basis @ matrix[:3, :3] * units[metadata["units"]]
    if abs(np.linalg.det(linear)) < 1e-12:
        raise ValueError("singular source transform")
    mesh["positions"] = (np.asarray(mesh["positions"]) @ linear.T + basis @ matrix[:3, 3] * units[metadata["units"]]).tolist()
    normals = np.asarray(mesh["normals"]) @ np.linalg.inv(linear)
    normals /= np.linalg.norm(normals, axis=1)[:, None]
    mesh["normals"] = normals.tolist()
    if np.linalg.det(linear) < 0:
        mesh["triangles"] = [t[::-1] for t in mesh["triangles"]]
        mesh["sourceFaces"] = [f[::-1] for f in mesh.get("sourceFaces", [])]
    scale, residual = register(mesh, metadata["landmarks"], style["templates"][template_id])
    mesh["normalization"] = {"sourceHash": digest(source.read_bytes()), "metadataHash": digest(canonical(metadata)),
                             "templateHash": digest(canonical(style["templates"][template_id])), "uniformScale": scale, "residualM": residual}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(canonical(mesh))
    if canonical(load_mesh(output)) != canonical(mesh):
        raise ValueError("mesh reimport mismatch")
    return mesh["normalization"]
