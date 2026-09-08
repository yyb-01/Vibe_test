"""Check documented POD layouts and reference arithmetic; not a C++ compiler."""
from pathlib import Path
import math
import re
import sqlite3

doc = Path(__file__).with_name("SURVIVAL_TECHNICAL_SPECIFICATION.md").read_text(encoding="utf-8")
cpp = "\n".join(re.findall(r"```cpp\n(.*?)```", doc, re.S))
cpp = re.sub(r"//[^\n]*", "", cpp)
types = {"float": (4, 4), "double": (8, 8)}
for bits in (8, 16, 32, 64):
    for sign in ("int", "uint"):
        types[f"std::{sign}{bits}_t"] = (bits // 8, bits // 8)


def align(value, boundary):
    return (value + boundary - 1) // boundary * boundary


# ponytail: this document's POD grammar only; use native compilers for ABI validation.
offsets = {}
structs = re.findall(r"struct\s+(?:alignas\((\d+)\)\s+)?(\w+)\s*\{([^}]+)\};", cpp)
for requested, name, body in structs:
    size, boundary = 0, int(requested or 1)
    for field in filter(None, (x.strip() for x in body.split(";"))):
        kind, declarations = field.split(None, 1)
        width, natural = types[kind]
        boundary = max(boundary, natural)
        for declaration in declarations.split(","):
            match = re.fullmatch(r"(\w+)(?:\[(\d+|N)\])?", declaration.strip())
            assert match, declaration
            member, count = match.groups()
            size = align(size, natural)
            offsets[name, member] = size
            size += width * (8 if count == "N" else int(count or 1))
    types[name] = (align(size, boundary), boundary)

checks = re.findall(r"sizeof\((\w+)(?:<8>)?\)\s*==\s*(\d+)", cpp)
for name, expected in checks:
    assert types[name][0] == int(expected), (name, types[name], expected)
for name, member, expected in re.findall(r"offsetof\((\w+),\s*(\w+)\)\s*==\s*(\d+)", cpp):
    assert offsets[name, member] == int(expected)

assert sum((12, 2, 4, 2, 8, 4, 2)) == 34  # FireIntent
assert sum((16, 4, 2, 4, 4, 2, 8, 16, 8)) == 64
assert "expectedInputRev(u64)=64B" in doc
assert sum((14, 12, 4, 12, 8, 12, 4, 2)) == 68
assert "0.05mm" in doc and "rotationXYZW[4]" in doc

def srgb(v):
    v /= 255
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

assert math.isclose(srgb(30), 0.01298303234, abs_tol=1e-10)
assert math.isclose(srgb(240), 0.8713671192, abs_tol=1e-10)
assert 2 ** (math.floor(math.log2(4000)) - 23) > 1e-6
assert 2 * 0.5 * math.sin(3e-6 / 2) > 1e-6
x = v = 0.0
for _ in range(240):
    x += (v - 9.80665 / 480) / 240
    v -= 9.80665 / 240
assert math.isclose(x, -4.903325, abs_tol=1e-10)
masses, positions = (2, 3), (0, 2)
com = sum(m * r for m, r in zip(masses, positions)) / sum(masses)
inertia = 0.5 + sum(m * (r - com) ** 2 for m, r in zip(masses, positions))
assert math.isclose(com, 1.2) and math.isclose(inertia, 5.3)
print(f"PASS: {len(structs)} POD layouts, {len(checks)} sizes, packets and reference arithmetic")

# Validate the documented schema excerpt, not persistence or crash recovery.
schema = next(s for s in re.findall(r"```sql\n(.*?)```", doc, re.S)
              if s.startswith("CREATE TABLE item"))
db = sqlite3.connect(":memory:")
try:
    db.execute("PRAGMA foreign_keys=ON")
    db.executescript(schema)
    assert db.execute("PRAGMA foreign_key_check").fetchall() == []
finally:
    db.close()
print("PASS: documented SQLite schema")
