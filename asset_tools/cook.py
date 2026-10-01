import shutil
import struct
import tempfile
from pathlib import Path
import numpy as np
from .bake import tangents
from .binary import check_header, cook_header
from .common import canonical, digest, local_file, read_json
from .mesh_io import load_mesh
from .signing import sign, verified
from .validate import validate
from .compression import compress_textures, dds_info

def cook(path, style_path, asset_approval, style_approval, trusted, private, destination):
    path, destination = Path(path), Path(destination)
    manifest, style, report = read_json(path), read_json(style_path), validate(path, style_path)
    if report["status"] != "passed":
        raise ValueError("asset validation failed: "+",".join(e["rule"] for e in report["errors"]))
    for approval, kind, subject in ((asset_approval, "asset", report["contentHash"]), (style_approval, "style", report["styleHash"])):
        payload = verified(approval, trusted)
        if payload["kind"] != kind or payload["subjectHash"] != subject:
            raise ValueError("approval hash/kind mismatch")
    if destination.exists():
        raise ValueError("cook preserves published versions; output already exists")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=destination.parent) as temporary:
        package = Path(temporary) / "package"
        package.mkdir()
        for name in report["artifactHashes"]:
            file = package / "sources" / name
            file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(local_file(path.parent, name), file)
        for name, value in (("source-manifest.json", manifest), ("style.json", style), ("validation.json", report),
                            ("skeleton.json", style["skeleton"]), ("physics.json", manifest["physics"])):
            (package / name).write_bytes(canonical(value))
        for name, source in (("asset-approval.json", asset_approval), ("style-approval.json", style_approval)):
            shutil.copyfile(source, package / name)
        lods = []
        for i, lod in enumerate(manifest["lods"]):
            mesh = load_mesh(local_file(path.parent, lod["mesh"]))
            faces = np.asarray(mesh["triangles"], int)
            values = np.concatenate([np.asarray(mesh[k])[faces] for k in ("positions", "normals", "uv")]+[tangents(mesh)], axis=2).astype("<f4")
            name = f"lod{i}.mesh"
            (package / name).write_bytes(struct.pack("<4sIII", b"AMES", 1, len(faces)*3, len(faces))+values.tobytes())
            lods.append({"file": name, "triangles": len(faces), "sourceTriangulation": digest(canonical(mesh["triangles"])), "tangentBasis": "MikkTSpace"})
        texture_files = compress_textures(manifest, path.parent, package)
        (package / "textures.json").write_bytes(canonical(texture_files))
        golden_file = local_file(path.parent, manifest["golden"])
        shutil.copyfile(local_file(golden_file.parent, "perspective.png"), package / "thumbnail.png")
        files = {p.relative_to(package).as_posix(): digest(p.read_bytes()) for p in package.rglob("*") if p.is_file()}
        graph = {"assetId": manifest["assetId"], "version": manifest["assetVersion"], "files": files, "lods": lods, "textures": texture_files}
        content = digest(canonical(graph))
        header, sockets = cook_header(manifest, report, style, lods, content)
        check_header(header)
        (package / "asset.bin").write_bytes(header)
        (package / "sockets.bin").write_bytes(sockets)
        payload = {"kind": "cook", "graph": graph, "contentHash": content, "assetBinHash": digest(header), "socketTableHash": digest(sockets),
                   "format": "windows_bc7_bc5_v1", "platformCompressionRequired": False}
        (package / "cook-manifest.json").write_bytes(canonical(sign(payload, private)))
        verify(package, trusted)
        package.rename(destination)
    return payload

def verify(package, trusted):
    package = Path(package)
    payload = verified(package / "cook-manifest.json", trusted)
    if payload["kind"] != "cook" or payload["contentHash"] != digest(canonical(payload["graph"])):
        raise ValueError("cook graph hash")
    for name, expected in payload["graph"]["files"].items():
        if digest(local_file(package, name).read_bytes()) != expected:
            raise ValueError("cook dependency changed: "+name)
    for row in payload["graph"].get("textures", {}).values():
        info = dds_info(local_file(package, row["file"]))
        if any(row[k] != info[k] for k in info): raise ValueError("cook DDS metadata")
    data = local_file(package, "asset.bin").read_bytes()
    fields = check_header(data)
    if digest(data) != payload["assetBinHash"] or fields[3].hex() != payload["contentHash"] or digest(local_file(package, "sockets.bin").read_bytes()) != payload["socketTableHash"]:
        raise ValueError("cook header/socket integrity")
    return payload
