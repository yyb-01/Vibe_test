import hashlib
import json
from pathlib import Path
from game_launcher.common import decode_json

FILE_LIMIT = 64 * 1024 * 1024

def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode()

def digest(data):
    return hashlib.sha256(data).hexdigest()

def local_file(root, name):
    if not isinstance(name, str) or not name or name.startswith("/") or ":" in name or "\\" in name:
        raise ValueError("invalid asset dependency path")
    root = Path(root).resolve()
    file = (root / name).resolve()
    if not file.is_relative_to(root) or not file.is_file() or file.is_symlink():
        raise ValueError("asset dependency outside source")
    if file.stat().st_size > FILE_LIMIT:
        raise ValueError("asset file budget")
    return file

def read_json(path):
    path = Path(path)
    if path.stat().st_size > FILE_LIMIT:
        raise ValueError("JSON budget")
    return decode_json(path.read_bytes())

class Report:
    def __init__(self, manifest):
        self.value = {"assetId": manifest.get("assetId"), "status": "failed", "errors": [],
                      "warnings": [], "metrics": {}, "artifactHashes": {}, "reviewRequired": True}

    def check(self, condition, rule, **details):
        if not bool(condition):
            self.value["errors"].append({"rule": rule, **details})

    def finish(self):
        self.value["status"] = "passed" if not self.value["errors"] else "failed"
        return self.value
