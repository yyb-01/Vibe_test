import asyncio
import secrets
from .common import atomic_json, decode_json

class LocalClient:
    def __init__(self, bridge, path):
        self.bridge, self.path, self.lock = bridge, path, asyncio.Lock()
        self.saved = decode_json(path.read_bytes()) if path.exists() else {
            "nonce": secrets.randbits(62) | 1, "sequence": 0, "pending": None}

    async def call(self, text):
        async with self.lock:
            if text == "show":
                return await self.bridge.call(1, "1:1", text)
            pending = self.saved["pending"]
            if pending and pending["command"] != text:
                return {"code": 16, "pending": pending["command"]}
            if not pending:
                self.saved["sequence"] += 1
                pending = self.saved["pending"] = {
                    "id": f'{self.saved["nonce"]}:{self.saved["sequence"]}', "command": text}
                atomic_json(self.path, self.saved)
            reply = await self.bridge.call(1, pending["id"], pending["command"])
            if reply.get("code") not in {15, 16, 17}:
                self.saved["pending"] = None
                atomic_json(self.path, self.saved)
            return reply
