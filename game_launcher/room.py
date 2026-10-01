import asyncio
import re
import secrets
import time
from urllib.parse import urlencode
from .common import PROTOCOL, receive, send
from .clock import RemoteClock, fire_command

class Budget:
    def __init__(self):
        self.buckets = {}

    def allow(self, group, rate, burst):
        now = time.monotonic()
        credit, last = self.buckets.get(group, (burst, now))
        credit = min(burst, credit + (now - last) * rate)
        allowed = credit >= 1
        self.buckets[group] = (credit - int(allowed), now)
        return allowed

class Room:
    def __init__(self, bridge, identity):
        self.bridge, self.identity = bridge, identity
        self.clients = {}
        self.budgets = {}
        self.pending = 0
        self.server = None
        self.handlers = set()

    async def presence(self, slot, online):
        reply = await self.bridge.call(slot, f"{secrets.randbits(62) | 1}:1", f"online {int(online)}")
        if reply.get("code") != 0:
            raise RuntimeError("presence persistence failed")

    async def open(self, address="0.0.0.0", port=7777):
        self.server = await asyncio.start_server(self.handle, address, port, ssl=self.identity.context,
                                               ssl_handshake_timeout=5, limit=8192, backlog=20)
        return self.server.sockets[0].getsockname()[1]

    def invitation(self, address, port, world):
        return f"astra://{address}:{port}/{world}?" + urlencode({
            "invite": self.identity.invite, "cert": self.identity.fingerprint})

    async def handle(self, reader, writer):
        key = None
        task = asyncio.current_task()
        self.handlers.add(task)
        self.pending += 1
        try:
            if self.pending > 40:
                raise ValueError("handshake budget")
            hello = await receive(reader, timeout=5)
            if not isinstance(hello, dict) or set(hello) != {"protocol", "content", "invite", "resume", "name", "channel"}:
                raise ValueError("handshake shape")
            channel = hello["channel"]
            if hello["protocol"] != PROTOCOL or hello["content"] != self.identity.content or channel not in {"commands", "view"}:
                raise ValueError("protocol/content mismatch")
            slot = await asyncio.to_thread(self.identity.bind, hello["invite"], hello["resume"], hello["name"], channel == "view")
            key = slot, channel
            old = self.clients.get(key)
            if old:
                old.close()
            self.clients[key] = writer
            await self.presence(slot, True)
            budget = self.budgets.setdefault(slot, Budget())
            clock = RemoteClock(self.bridge, slot)
            await send(writer, {"joined": True, "slot": slot, "protocol": PROTOCOL})
            while True:
                message = await receive(reader, timeout=60)
                if channel=="commands" and isinstance(message,dict) and set(message)=={"ping"}:
                    if not budget.allow("clock", 10, 20):raise ValueError("clock budget")
                    await send(writer,await clock.begin(message["ping"]));continue
                if channel=="commands" and isinstance(message,dict) and set(message)=={"clock", "client"}:
                    await send(writer,await clock.finish(message["clock"],message["client"]));continue
                if not isinstance(message, dict) or set(message) not in ({"id", "command"},{"id", "command", "fire"}):
                    raise ValueError("command shape")
                request, text = message["id"], message["command"]
                if not isinstance(request, str) or not re.fullmatch(r"[0-9]{1,20}:[0-9]{1,20}", request):
                    raise ValueError("request ID")
                if not isinstance(text, str) or not text.strip() or len(text) > 1800 or not text.isascii() or any(ord(c) < 32 for c in text):
                    raise ValueError("command text")
                verb = text.split()[0]
                if verb in {"tick", "online", "sync", "r-fire"} or (channel == "view" and text != "show") or (channel == "commands" and text == "show") or ((verb=="fire") != ("fire" in message)):
                    raise ValueError("channel authority")
                group, rate, burst = ("view", 5, 5) if channel == "view" else ("input", 60, 60) if verb in {"move", "aim", "drive"} else ("fire", 30, 30) if verb in {"fire", "trigger"} else ("economic", 10, 20)
                if verb=="fire":text=fire_command(message)
                reply = await self.bridge.call(slot, request, text) if budget.allow(group, rate, burst) else {"code": 16}
                await send(writer, reply)
        except (ValueError, OSError, TimeoutError, asyncio.IncompleteReadError, RuntimeError):
            pass  # Malformed/untrusted sessions never reach the authority bridge.
        finally:
            self.pending -= 1
            if key and self.clients.get(key) is writer:
                del self.clients[key]
                if not any(k[0] == key[0] for k in self.clients):
                    try:
                        await self.presence(key[0], False)
                    except (RuntimeError, OSError, TimeoutError):
                        pass
            writer.close()
            try:
                await asyncio.wait_for(writer.wait_closed(),5)
            except (OSError,TimeoutError):
                pass
            self.handlers.discard(task)

    async def close(self):
        if self.server:
            self.server.close()
            await self.server.wait_closed()
        for writer in list(self.clients.values()):
            writer.close()
        if self.handlers:
            await asyncio.gather(*list(self.handlers), return_exceptions=True)
