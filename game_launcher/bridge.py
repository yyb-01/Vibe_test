import asyncio
import json
import secrets
from .common import ROOT, LIMIT, decode_json

class Bridge:
    def __init__(self, process):
        self.process = process
        self.lock = asyncio.Lock()
        self.failed = False
        self.tick_nonce = 1
        self.tick_origin = secrets.randbits(62) | 1

    @classmethod
    async def open(cls, path, executable=None):
        process = await asyncio.create_subprocess_exec(
            str(executable or ROOT / ".build" / "astra-game.exe"), "--save", str(path),
            stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, limit=LIMIT)
        bridge = cls(process)
        if await bridge.read() != {"ready": True, "protocol": 1}:
            raise RuntimeError("game recovery failed")
        return bridge

    async def read(self):
        try:
            data = await asyncio.wait_for(self.process.stdout.readline(), 15)
            if not data or len(data) > LIMIT:
                raise RuntimeError("game process stopped")
            return decode_json(data)
        except BaseException:
            self.failed = True
            raise

    async def call(self, slot, request, text):
        if self.failed or not isinstance(text, str) or not 0 < len(text) <= 1800 or any(ord(c) < 32 for c in text):
            raise ValueError("invalid game command")
        async with self.lock:
            self.process.stdin.write(f"{slot} {request} {text}\n".encode("ascii"))
            await self.process.stdin.drain()
            return await self.read()

    async def ticks(self, stop):
        pending = None
        while not stop.is_set():
            start = asyncio.get_running_loop().time()
            if pending is None:
                self.tick_nonce += 1
                pending = f"{self.tick_origin}:{self.tick_nonce}"
            result = await self.call(0, pending, "tick")
            if result["code"] == 0:
                pending = None
            elif result["code"] not in {15, 16, 17}:
                raise RuntimeError(f"simulation stopped: {result}")
            await asyncio.sleep(max(0.001, 1 / 60 - (asyncio.get_running_loop().time() - start)))

    async def close(self):
        async with self.lock:
            if not self.failed:
                for _ in range(30):
                    self.process.stdin.write(b"quit\n")
                    await self.process.stdin.drain()
                    reply = await self.read()
                    if reply.get("closed"):
                        self.process.stdin.close()
                        return await asyncio.wait_for(self.process.wait(), 5) == 0
                    await asyncio.sleep(0.1)
            self.process.stdin.close()
            return await asyncio.wait_for(self.process.wait(), 10) == 0
