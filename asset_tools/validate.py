import uuid
import subprocess
from pathlib import Path
import numpy as np
from .common import Report, canonical, digest, local_file, read_json
from .datum import datum
from .mesh_io import load_mesh
from .textures import textures
from .topology import check_mesh

def validate(path, style_path):
    path = Path(path).resolve()
    manifest, style = read_json(path), read_json(style_path)
    root, report = Path(path).parent, Report(manifest)
    try:
        uuid.UUID(manifest["assetId"])
        report.check(manifest.get("schema") == 1 and isinstance(manifest.get("assetVersion"), int) and manifest["assetVersion"] > 0, "MANIFEST_VERSION")
        report.check(manifest.get("units") == "metre" and manifest.get("basis") == "RH_Xforward_Yleft_Zup" and manifest.get("rootScale") == [1, 1, 1], "CANONICAL_TRANSFORM")
        report.check(manifest.get("stylePack") == style["id"] and manifest.get("styleHash") == digest(canonical(style)), "STYLE_VERSION")
        profile, template = style["classes"][manifest["assetClass"]], style["templates"][manifest["templateId"]]
        materials = manifest["materials"]
        report.check(0 < len(materials) <= profile["materials"] and all(m in style["materials"] for m in materials), "MATERIAL_LIBRARY")
        report.check(all(style["materials"][m]["master"] in style["masters"] for m in materials), "MASTER_FAMILY")
        provenance = manifest.get("provenance", {})
        report.check(all(provenance.get(k) for k in ("source", "license", "prompt", "modelVersion", "toolVersion", "inputHash")) and "seed" in provenance, "SOURCE_PROVENANCE")
        arrays = textures(manifest, style, root, report)
        lods = manifest["lods"]
        report.check(0 < len(lods) <= 8, "LOD_COUNT")
        previous = profile["triangles"]
        for index, lod in enumerate(lods):
            file = local_file(root, lod["mesh"])
            mesh = load_mesh(file)
            count = len(mesh["triangles"])
            report.check(count <= previous, "LOD_TRIANGLE_BUDGET", lod=index, count=count, limit=previous)
            previous = count
            report.value["artifactHashes"][lod["mesh"]] = digest(file.read_bytes())
            area, uv = check_mesh(mesh, report, manifest.get("closed", True), manifest.get("deform", False), f"LOD{index}")
            datum(manifest, mesh, template, report)
            bounds = np.concatenate((np.min(mesh["positions"], axis=0), np.max(mesh["positions"], axis=0)))
            report.check(np.max(np.abs(bounds - np.asarray(manifest["boundsM"]))) <= .00005, "LOD_BOUNDS", lod=index)
            if "baseColor" in arrays:
                height, width = arrays["baseColor"].shape[:2]
                uv_area = np.abs(np.cross(uv[:, 1]-uv[:, 0], uv[:, 2]-uv[:, 0])) / 2
                density = np.sqrt(uv_area * height * width / np.maximum(area, 1e-30))
                report.check(np.all(np.abs(density / profile["density"]-1) <= .1), "TEXEL_DENSITY", lod=index)
            report.check(lod.get("gutterPxAt2K", 0) >= 16 and lod.get("dilationPxAt2K", 0) >= 8, "UV_PADDING", lod=index)
            if manifest.get("deform"):
                for weights in mesh.get("skin", []):
                    report.check(1 <= len(weights) <= 4 and abs(sum(w for _, w in weights)-1) <= 1e-5 and all(b in style["skeleton"] and w >= 0 for b, w in weights), "SKIN_WEIGHTS")
                report.check(len(mesh.get("skin", [])) == len(mesh["positions"]), "SKIN_VERTEX_COUNT")
            if index == 0:
                report.value["metrics"].update(triangles=count, vertices=len(mesh["positions"]), materialSlots=len(materials))
        collision_file = local_file(root, manifest["collision"])
        collision = load_mesh(collision_file)
        check_mesh(collision, report, True, False, "COLLISION")
        report.value["artifactHashes"][manifest["collision"]] = digest(collision_file.read_bytes())
        physics = manifest["physics"]
        inertia = np.asarray(physics["inertiaKgM2"], float)
        report.check(physics["massKg"] > 0 and inertia.shape == (3, 3) and np.max(np.abs(inertia-inertia.T)) <= 1e-6 and np.min(np.linalg.eigvalsh(inertia)) > 0, "PHYSICS_MASS_INERTIA")
        low = np.min(collision["positions"], axis=0)
        high = np.max(collision["positions"], axis=0)
        visual = np.asarray(manifest["boundsM"])
        report.check(np.max(np.abs(np.concatenate((low, high))-visual)) <= .005, "GAMEPLAY_COLLISION_ALIGNMENT")
        if not report.value["errors"]:
            from .bake import verify_bake
            verify_bake(manifest, root, report)
            from .golden import verify_golden
            verify_golden(manifest, root, report)
    except (ValueError, KeyError, TypeError, IndexError, OverflowError, OSError, subprocess.SubprocessError, np.linalg.LinAlgError) as error:
        report.check(False, "INVALID_FORMAT", message=str(error))
    report.value["styleHash"] = digest(canonical(style))
    report.value["contentHash"] = digest(canonical({"manifest": manifest, "dependencies": report.value["artifactHashes"]}))
    return report.finish()
