import struct
import uuid
from .common import canonical

HEADER = struct.Struct("<QQ32s32s8I4HfI")
SOCKET = struct.Struct("<QQ3q4dIHH")

def identifier(text):
    n = uuid.UUID(text).int
    return n >> 64, n & ((1 << 64)-1)

def cook_header(manifest, report, style, lods, content_hash):
    sockets = manifest["sockets"]
    if len(sockets) > 256 or len(lods) > 8 or len(manifest["materials"]) > 8:
        raise ValueError("cook table budget")
    socket_bytes = b"".join(SOCKET.pack(*identifier(s["id"]), *s["positionNm"], *s["rotationXYZW"], s["profileId"], s["gender"], s["keyVariant"]) for s in sockets)
    sections = [socket_bytes]
    for value in ([{"id": m, **style["materials"][m]} for m in manifest["materials"]], manifest["physics"], lods):
        data = canonical(value)
        sections.append(struct.pack("<I", len(data))+data)
    offsets, body = [], bytearray()
    for section in sections:
        body.extend(b"\0"*((-len(body)) % 8))
        offsets.append(128+len(body))
        body.extend(section)
    header = HEADER.pack(*identifier(manifest["assetId"]), bytes.fromhex(report["styleHash"]), bytes.fromhex(content_hash),
                         1, manifest["assetVersion"], *offsets, report["metrics"]["triangles"], report["metrics"]["vertices"],
                         len(sockets), len(lods), len(manifest["materials"]), 1, 1., 0)
    return header+body, socket_bytes

def check_header(data):
    if len(data) < 128:
        raise ValueError("cook header truncated")
    fields = HEADER.unpack_from(data)
    if fields[4] != 1 or not fields[5] or fields[-2:] != (1., 0) or fields[15] != 1:
        raise ValueError("cook schema/transform")
    offsets = fields[6:10]
    if offsets[0] != 128 or list(offsets) != sorted(offsets) or any(n % 8 or n > len(data) for n in offsets):
        raise ValueError("cook offsets")
    if fields[12] > 256 or not 1 <= fields[13] <= 8 or not 1 <= fields[14] <= 8 or offsets[0]+fields[12]*80 > offsets[1]:
        raise ValueError("cook counts")
    for i in range(1, 4):
        offset = offsets[i]
        if offset+4 > len(data):
            raise ValueError("cook table truncated")
        n, = struct.unpack_from("<I", data, offset)
        end = offsets[i+1] if i < 3 else len(data)
        if offset+4+n > end:
            raise ValueError("cook table bounds")
    return fields
