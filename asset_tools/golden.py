from pathlib import Path
import numpy as np
from PIL import Image
from .common import canonical, digest, local_file, read_json
from .mesh_io import load_mesh
from .bake import tangents

PRESET = {"whitePoint": "D65", "autoExposure": False, "exposure": 1, "grayCardLinear": .18,
          "renderer": "astra_cpu_reference_v1", "toneMapper": "linear_to_sRGB", "AA": "none", "environment": "constant_D65_1"}
VIEWS = {"front": [1, 0, 0], "side": [0, -1, 0], "top": [0, 0, 1], "perspective": [1, -1, 1],
         "grazing": [1, -.1, .1], "assembly": [1, -1, .5], "gameplay": [1, -1, 1], "wet": [1, -1, 1], "night": [1, -1, 1]}

def srgb(x):
    return np.where(x <= .0031308, 12.92*x, 1.055*np.maximum(x, 0)**(1/2.4)-.055)

def render(mesh, textures, view, size, tangent):
    positions = np.asarray(mesh["positions"], float)
    normals, uv, indices = (np.asarray(mesh[k]) for k in ("normals", "uv", "triangles"))
    camera = np.asarray(VIEWS[view], float); camera /= np.linalg.norm(camera)
    right = np.cross([0, 1, 0] if view == "top" else [0, 0, 1], camera); right /= np.linalg.norm(right)
    up = np.cross(camera, right)
    local = positions-(positions.min(axis=0)+positions.max(axis=0))/2
    extent = max(np.ptp(local @ right), np.ptp(local @ up), 1e-8)*1.3*(3 if view == "gameplay" else 1)
    screen = np.column_stack((local @ right, -(local @ up)))/extent*size+size/2
    depth = local @ camera
    z = np.full((size, size), -np.inf)
    output = np.full((size, size, 3), srgb(.03))
    buffers = {k: np.zeros_like(output) for k in ("baseColor", "roughness", "metallic", "normal", "ao", "coverage")}
    for ordinal, face in enumerate(indices):
        triangle = screen[face]; matrix = np.column_stack((triangle[1]-triangle[0], triangle[2]-triangle[0]))
        if abs(np.linalg.det(matrix)) < 1e-12:
            continue
        begin = np.maximum(0, np.floor(triangle.min(axis=0)).astype(int)); end = np.minimum(size-1, np.ceil(triangle.max(axis=0)).astype(int))
        if (begin > end).any():
            continue
        yy, xx = np.mgrid[begin[1]:end[1]+1, begin[0]:end[0]+1]
        ab = (np.stack((xx+.5, yy+.5), axis=-1)-triangle[0]) @ np.linalg.inv(matrix).T
        weights = np.stack((1-ab[..., 0]-ab[..., 1], ab[..., 0], ab[..., 1]), axis=-1)
        d = weights @ depth[face]; mask = (weights.min(axis=-1) >= -1e-10) & (d > z[yy, xx])
        y, x, weights = yy[mask], xx[mask], weights[mask]
        if not len(x):
            continue
        z[y, x] = d[mask]
        coords = np.clip(weights @ uv[face], 0, 1)
        h, w = textures["baseColor"].shape[:2]
        tx, ty = np.minimum(w-1, (coords[:, 0]*w).astype(int)), np.minimum(h-1, ((1-coords[:, 1])*h).astype(int))
        base = textures["baseColor"][ty, tx, :3]/255
        linear = np.where(base <= .04045, base/12.92, ((base+.055)/1.055)**2.4)
        orm = textures["orm"][ty, tx, :3]/255
        normal = weights @ normals[face]; normal /= np.linalg.norm(normal, axis=1)[:, None]
        t = weights @ tangent[ordinal, :, :3]; t -= normal*np.sum(t*normal, axis=1)[:, None]; t /= np.linalg.norm(t, axis=1)[:, None]
        b = np.cross(normal, t)*np.where(weights @ tangent[ordinal, :, 3] >= 0, 1, -1)[:, None]
        xy = textures["normal"][ty, tx, :2]/127.5-1
        normal = t*xy[:, :1]-b*xy[:, 1:2]+normal*np.sqrt(np.maximum(0, 1-(xy*xy).sum(axis=1)))[:, None]
        normal /= np.linalg.norm(normal, axis=1)[:, None]
        lighting = .15+.85*np.maximum(0, normal @ np.array([.577350269]*3))
        if view == "grazing":
            lighting = .05+.95*np.maximum(0, normal @ np.array([.995037, 0, .0995037]))
        roughness = orm[:, 1]*.6 if view == "wet" else orm[:, 1]
        specular = (.04*(1-orm[:, 2])+orm[:, 2])*(1-roughness)*np.maximum(0, normal @ camera)**32
        shade = linear*lighting[:, None]*orm[:, :1]+specular[:, None]*.15
        if view == "night":
            shade *= .04
        output[y, x] = srgb(shade)
        values = (base, np.repeat(roughness[:, None], 3, axis=1), np.repeat(orm[:, 2:3], 3, axis=1), normal*.5+.5, np.repeat(orm[:, :1], 3, axis=1), np.ones_like(base))
        for key, value in zip(buffers, values):
            buffers[key][y, x] = value
    output[-size//12:, :size//12] = srgb(.18)
    return output, buffers

def golden(manifest_path, output, size=256):
    if not 64 <= size <= 1024:
        raise ValueError("golden resolution budget")
    path, output = Path(manifest_path), Path(output)
    manifest = read_json(path); root = path.parent
    mesh = load_mesh(local_file(root, manifest["lods"][0]["mesh"]))
    textures = {k: np.asarray(Image.open(local_file(root, manifest["textures"][k]["file"])).convert("RGB")) for k in ("baseColor", "orm", "normal")}
    tangent = tangents(mesh)
    output.mkdir(parents=True, exist_ok=True)
    hashes = {}
    for view in VIEWS:
        image, debug = render(mesh, textures, view, size, tangent)
        rows = {view: image, **({"debug_"+k: v for k, v in debug.items()} if view == "perspective" else {})}
        for name, pixels in rows.items():
            file = output / (name+".png")
            Image.fromarray(np.clip(np.rint(pixels*255), 0, 255).astype("uint8")).save(file)
            hashes[file.name] = digest(file.read_bytes())
    value = {"preset": PRESET, "presetHash": digest(canonical(PRESET)), "resolution": size,
             "inputHash": digest(canonical(manifest)), "files": hashes, "reviewRequired": True,
             "limits": "CPU reference views; renderer compression, skin poses and assembly sweep require target-renderer review"}
    (output / "golden.json").write_bytes(canonical(value))
    return value

def verify_golden(manifest, root, report):
    file = local_file(root, manifest["golden"])
    value = read_json(file)
    report.check(value["preset"] == PRESET and value["presetHash"] == digest(canonical(PRESET)) and value["inputHash"] == digest(canonical(manifest)), "GOLDEN_PRESET_INPUT")
    required = {v+".png" for v in VIEWS} | {"debug_"+v+".png" for v in ("baseColor", "roughness", "metallic", "normal", "ao", "coverage")}
    report.check(set(value["files"]) == required, "GOLDEN_VIEWS_BUFFERS")
    size=value["resolution"]
    if type(size) is not int or not 64<=size<=1024:raise ValueError("golden resolution budget")
    mesh=load_mesh(local_file(root,manifest["lods"][0]["mesh"]))
    textures={k:np.asarray(Image.open(local_file(root,manifest["textures"][k]["file"])).convert("RGB")) for k in ("baseColor","orm","normal")}
    tangent=tangents(mesh);rendered={}
    for view in VIEWS:
        pixels,debug=render(mesh,textures,view,size,tangent)
        rendered[view+".png"]=pixels
        if view=="perspective":rendered.update({"debug_"+key+".png":pixels for key,pixels in debug.items()})
    for name, expected in value["files"].items():
        image = local_file(file.parent, name)
        report.check(digest(image.read_bytes()) == expected, "GOLDEN_FILE_HASH", file=name)
        pixels=np.asarray(Image.open(image).convert("RGB"));reference=np.clip(np.rint(rendered[name]*255),0,255).astype("uint8")
        report.check(pixels.shape==reference.shape and np.array_equal(pixels,reference),"GOLDEN_RENDER_MATCH",file=name)
        report.value["artifactHashes"][image.relative_to(root).as_posix()] = digest(image.read_bytes())
    report.value["artifactHashes"][manifest["golden"]] = digest(file.read_bytes())
