"""Bounded JSON framing shared by the TLS room and local UI."""
import asyncio
import json
import os
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIMIT = 2 * 1024 * 1024
PROTOCOL = 2

def decode_json(data):
    def pairs(rows):
        result = {}
        for key, value in rows:
            if key in result:
                raise ValueError("duplicate JSON key")
            result[key] = value
        return result
    return json.loads(data, object_pairs_hook=pairs,
                      parse_constant=lambda _: (_ for _ in ()).throw(ValueError("non-finite JSON")))

async def receive(reader, limit=4096, timeout=10):
    length, = struct.unpack("!I", await asyncio.wait_for(reader.readexactly(4), timeout))
    if not 0 < length <= limit:
        raise ValueError("frame limit")
    return decode_json(await asyncio.wait_for(reader.readexactly(length), timeout))

async def send(writer, value):
    data = json.dumps(value, separators=(",", ":"), allow_nan=False).encode()
    if len(data) > LIMIT:
        raise ValueError("reply limit")
    writer.write(struct.pack("!I", len(data)) + data)
    await asyncio.wait_for(writer.drain(), 5)

def world_path(name, test_root=None):
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,48}", name) or name.upper() in {
        "CON", "PRN", "AUX", "NUL", *(f"COM{i}" for i in range(10)), *(f"LPT{i}" for i in range(10))}:
        raise ValueError("invalid worldId")
    root = Path(test_root).resolve() if test_root else Path(os.environ["LOCALAPPDATA"]) / "AstraGame" / "Saves"
    directory = root / name
    directory.mkdir(parents=True, exist_ok=True)
    return directory / "world.sqlite3"

def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    with open(temporary, "w", encoding="utf8") as output:
        json.dump(value, output, separators=(",", ":"), allow_nan=False)
        output.flush()
        os.fsync(output.fileno())
    os.chmod(temporary, 0o600)
    os.replace(temporary, path)
