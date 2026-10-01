import base64
import struct
import numpy as np
from .common import FILE_LIMIT, local_file, read_json
from game_launcher.common import decode_json

def gltf(path):
    binary = None
    if path.suffix.lower() == ".glb":
        data = path.read_bytes()
        if len(data) < 20 or struct.unpack_from("<III", data) != (0x46546C67, 2, len(data)):
            raise ValueError("GLB header")
        offset, chunks = 12, {}
        while offset < len(data):
            if offset + 8 > len(data):
                raise ValueError("GLB truncated chunk")
            length, kind = struct.unpack_from("<II", data, offset)
            offset += 8
            if length % 4 or offset + length > len(data) or kind in chunks:
                raise ValueError("GLB chunk")
            chunks[kind] = data[offset:offset + length]
            offset += length
        document = decode_json(chunks[0x4E4F534A])
        binary = chunks.get(0x004E4942)
    else:
        document = read_json(path)
    if not isinstance(document, dict) or document.get("asset", {}).get("version") != "2.0" or document.get("extensionsRequired"):
        raise ValueError("unsupported glTF version/extensions")
    buffers = []
    for row in document.get("buffers", []):
        uri = row.get("uri")
        if uri is None:
            data = binary
        elif uri.startswith("data:application/octet-stream;base64,"):
            data = base64.b64decode(uri.split(",", 1)[1], validate=True)
        else:
            data = local_file(path.parent, uri).read_bytes()
        if data is None or len(data) > FILE_LIMIT or not row["byteLength"] <= len(data) <= row["byteLength"] + 3:
            raise ValueError("glTF buffer length")
        buffers.append(data)
    types = {5120: "i1", 5121: "u1", 5122: "<i2", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
    sizes = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
    def accessor(index):
        if type(index) is not int or not 0 <= index < len(document["accessors"]):
            raise ValueError("glTF accessor index")
        a = document["accessors"][index]
        if "sparse" in a or type(a["count"]) is not int or not 0 < a["count"] <= 450000 or type(a["bufferView"]) is not int or not 0 <= a["bufferView"] < len(document["bufferViews"]):
            raise ValueError("sparse/accessor budget")
        view = document["bufferViews"][a["bufferView"]]
        if type(view["buffer"]) is not int or not 0 <= view["buffer"] < len(buffers):
            raise ValueError("glTF buffer index")
        data, dtype, width = buffers[view["buffer"]], np.dtype(types[a["componentType"]]), sizes[a["type"]]
        stride = view.get("byteStride", dtype.itemsize * width)
        start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
        end = start + (a["count"] - 1) * stride + dtype.itemsize * width
        if any(type(x) is not int or x < 0 for x in (stride, start, view["byteLength"], view.get("byteOffset", 0), a.get("byteOffset", 0))) or stride % dtype.itemsize or start % dtype.itemsize or stride < dtype.itemsize * width or end > len(data) or end > view.get("byteOffset", 0) + view["byteLength"]:
            raise ValueError("glTF accessor bounds")
        values = np.ndarray((a["count"], width), dtype=dtype, buffer=data, offset=start, strides=(stride, dtype.itemsize)).copy()
        if a.get("normalized") and dtype.kind in "iu":
            values = np.maximum(-1, values.astype(float) / np.iinfo(dtype).max)
        return values
    primitives = [p for mesh in document.get("meshes", []) for p in mesh["primitives"]]
    if len(primitives) != 1 or primitives[0].get("mode", 4) != 4 or document.get("skins"):
        raise ValueError("normalize a single rigid glTF primitive; skinned sources require canonical mesh metadata")
    for node in document.get("nodes", []):
        if "matrix" in node or node.get("scale", [1, 1, 1]) != [1, 1, 1] or node.get("rotation", [0, 0, 0, 1]) != [0, 0, 0, 1] or node.get("translation", [0, 0, 0]) != [0, 0, 0]:
            raise ValueError("freeze glTF object transforms before import")
    primitive = primitives[0]
    attributes = primitive["attributes"]
    index_accessor = document["accessors"][primitive["indices"]] if type(primitive["indices"]) is int and 0 <= primitive["indices"] < len(document["accessors"]) else {}
    if index_accessor.get("componentType") not in {5121, 5123, 5125} or index_accessor.get("type") != "SCALAR" or index_accessor.get("normalized"):
        raise ValueError("unsigned scalar glTF indices required")
    indices = accessor(primitive["indices"]).reshape(-1)
    if len(indices) % 3:
        raise ValueError("glTF triangle indices")
    return {"positions": accessor(attributes["POSITION"]).tolist(), "normals": accessor(attributes["NORMAL"]).tolist(),
            "uv": accessor(attributes["TEXCOORD_0"]).tolist(), "triangles": indices.reshape((-1, 3)).tolist()}
