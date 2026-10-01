import copy
import tempfile
from pathlib import Path
import numpy as np
from PIL import Image
from cryptography.exceptions import InvalidSignature
from asset_tools.bake import bake_normal
from asset_tools.binary import HEADER, SOCKET, check_header
from asset_tools.common import canonical, digest, read_json
from asset_tools.cook import cook, verify
from asset_tools.golden import golden
from asset_tools.mesh_io import load_mesh
from asset_tools.normalize import normalize
from asset_tools.signing import approval, keygen
from asset_tools.validate import validate
from asset_tools.color import delta_e

def fixture(root):
    p, normals, uv, triangles, quads = [], [], [], [], []
    for axis in range(3):
        for side in range(2):
            f = axis*2+side
            n = [0., 0., 0.]; n[axis] = 1 if side else -1
            corners = [(0, 0), (.1, 0), (.1, .1), (0, .1)]
            if not side:
                corners = corners[::-1]
            for j, (a, b) in enumerate(corners):
                point = [0., 0., 0.]; point[axis] = side*.1; point[(axis+1)%3] = a; point[(axis+2)%3] = b
                p.append(point); normals.append(n)
                u, v = [(0, 0), (.28, 0), (.28, .28), (0, .28)][j]
                uv.append([.035+(f%3)*.315+u, .05+(f//3)*.45+v])
            base = f*4; quads.append(list(range(base, base+4)))
            triangles.extend([[base, base+1, base+2], [base, base+2, base+3]])
    labels = {k: p.index(v) for k, v in {"origin": [0, 0, 0], "axis_x": [.1, 0, 0], "axis_y": [0, .1, 0]}.items()}
    mesh = {"positions": p, "normals": normals, "uv": uv, "triangles": triangles, "sourceFaces": quads, "landmarks": labels}
    style = read_json(Path("assets/style_pack.json")); style["id"] = "test_only_policy"; style["classes"]["part"]["density"] = 179.2
    (root / "style.json").write_bytes(canonical(style))
    for name in ("low.json", "high.json", "collision.json"):
        (root / name).write_bytes(canonical(mesh))
    for name, color in (("bc", [84, 92, 68, 255]), ("orm", [255, 128, 0, 255]), ("id", [1, 0, 0, 255])):
        Image.new("RGBA", (64, 64), tuple(color)).save(root / (name+".png"))
    bake = bake_normal(mesh, mesh, root / "normal.png", 64, .01)
    (root / "bake.json").write_bytes(canonical(bake))
    Image.open(root / "normal.png").save(root / "reference.png")
    manifest = {"schema": 1, "assetId": "00000000-0000-0000-0000-000000000100", "assetVersion": 1,
        "assetClass": "part", "stylePack": style["id"], "styleHash": digest(canonical(style)), "templateId": "datum_fixture_v1",
        "units": "metre", "basis": "RH_Xforward_Yleft_Zup", "rootScale": [1, 1, 1], "boundsM": [0, 0, 0, .1, .1, .1],
        "materials": ["painted_steel_olive_v1"], "normalConvention": "DirectX_Yminus_MikkTSpace", "closed": True,
        "textures": {k: {"file": file, "sRGB": k == "baseColor", **({"filter": "nearest"} if k == "id" else {})}
                     for k, file in (("baseColor", "bc.png"), ("orm", "orm.png"), ("id", "id.png"), ("normal", "normal.png"))},
        "lods": [{"mesh": "low.json", "gutterPxAt2K": 16, "dilationPxAt2K": 8}], "sockets": style["templates"]["datum_fixture_v1"]["sockets"],
        "collision": "collision.json", "physics": {"massKg": 1, "inertiaKgM2": np.eye(3).tolist()}, "golden": "golden/golden.json",
        "bake": {"high": "high.json", "report": "bake.json", "reference": "reference.png"},
        "provenance": {"source": "programmatic test cube", "license": "test fixture", "prompt": "deterministic cube", "modelVersion": "none", "toolVersion": "1", "inputHash": digest(canonical(mesh)), "seed": 1}}
    (root / "manifest.json").write_bytes(canonical(manifest))
    golden(root / "manifest.json", root / "golden", 64)
    return manifest, mesh

def checks(root):
    for a, b, expected in (([50,2.6772,-79.7751],[50,0,-82.7485],2.0425),([50,3.1571,-77.2803],[50,0,-82.7485],2.8615),([50,2.8361,-74.0200],[50,0,-82.7485],3.4412)):
        assert abs(float(delta_e(a,b))-expected) < .0001
    manifest, mesh = fixture(root)
    path, style = root / "manifest.json", root / "style.json"
    report = validate(path, style)
    assert report["status"] == "passed", report["errors"]
    assert HEADER.size == 128 and SOCKET.size == 80
    for mutate, expected in ((lambda m: m["sockets"][0]["positionNm"].__setitem__(0, 2000), "SOCKET_DATUM"),
                             (lambda m: m["textures"]["orm"].__setitem__("sRGB", True), "ORM_COLORSPACE"),
                             (lambda m: m.__setitem__("collision", "../escape.json"), "INVALID_FORMAT")):
        bad = copy.deepcopy(manifest); mutate(bad); path.write_bytes(canonical(bad))
        assert expected in {e["rule"] for e in validate(path, style)["errors"]}
    path.write_bytes(canonical(manifest))
    from asset_tools.common import local_file
    try:local_file(root,'/'+(root.resolve()/'low.json').as_posix().split(':')[-1].lstrip('/'));raise AssertionError('absolute dependency accepted')
    except ValueError:pass
    golden_report=read_json(root/'golden/golden.json');saved_golden=canonical(golden_report)
    image=root/'golden/perspective.png';saved_image=image.read_bytes();Image.new('RGB',(64,64),(0,0,0)).save(image)
    golden_report['files']['perspective.png']=digest(image.read_bytes());(root/'golden/golden.json').write_bytes(canonical(golden_report))
    assert 'GOLDEN_RENDER_MATCH' in {e['rule'] for e in validate(path,style)['errors']}
    image.write_bytes(saved_image);(root/'golden/golden.json').write_bytes(saved_golden)
    corrupt = copy.deepcopy(mesh); corrupt["triangles"].append(corrupt["triangles"][0]); (root / "low.json").write_bytes(canonical(corrupt))
    assert "LOD0_DUPLICATE_FACE" in {e["rule"] for e in validate(path, style)["errors"]}
    (root / "low.json").write_bytes(canonical(mesh))
    source = copy.deepcopy(mesh); source["positions"] = (np.asarray(source["positions"])*100).tolist()
    (root / "source.json").write_bytes(canonical(source)); original = (root / "source.json").read_bytes()
    (root / "source-meta.json").write_bytes(canonical({"units": "centimetre", "basis": manifest["basis"], "landmarks": mesh["landmarks"]}))
    normalize(root / "source.json", root / "source-meta.json", style, manifest["templateId"], root / "normalized.json")
    assert (root / "source.json").read_bytes() == original
    assert np.max(np.abs(np.asarray(load_mesh(root / "normalized.json")["positions"])-mesh["positions"])) < 1e-6
    private, public = root / "test-only-private.pem", root / "test-only-public.pem"
    keygen(private, public)
    try:
        cook(path, style, root / "unsigned.json", root / "unsigned.json", public, private, root / "blocked")
        raise AssertionError("unsigned publication passed")
    except FileNotFoundError:
        pass
    visual_checks = ["lighting", "seams", "clearance", "scale", "licensing"]
    approval("asset", report["contentHash"], "test fixture only", visual_checks, private, root / "asset-review.json")
    approval("style", report["styleHash"], "test fixture only", visual_checks, private, root / "style-review.json")
    payload = cook(path, style, root / "asset-review.json", root / "style-review.json", public, private, root / "package")
    assert not payload["platformCompressionRequired"]
    assert [payload["graph"]["textures"][kind]["format"] for kind in ("baseColor","normal","orm")] == [99,83,98]
    assert all(row["mips"] == 7 for row in payload["graph"]["textures"].values())
    verify(root / "package", public)
    data = (root / "package/asset.bin").read_bytes(); check_header(data)
    bad = bytearray(data); bad[88:92] = (0xffffffff).to_bytes(4, "little")
    try:
        check_header(bad); raise AssertionError("out-of-file cook offset passed")
    except ValueError:
        pass
    (root / "package/lod0.mesh").write_bytes(b"modified")
    try:
        verify(root / "package", public); raise AssertionError("modified signed dependency passed")
    except ValueError:
        pass
    signed = read_json(root / "package/cook-manifest.json"); signed["payload"]["contentHash"] = "0"*64
    (root / "package/cook-manifest.json").write_bytes(canonical(signed))
    try:
        verify(root / "package", public); raise AssertionError("forged signature passed")
    except InvalidSignature:
        pass
    print("PASS asset datum, topology, PBR, CIEDE2000, Mikk bake, golden buffers, BC7/BC5 mipchain, signed cook and tamper rejection")

if __name__ == "__main__":
    base = Path(".build/asset-tests"); base.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=base) as directory:
        checks(Path(directory))
