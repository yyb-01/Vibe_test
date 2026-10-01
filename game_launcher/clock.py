"""Authenticated ping/ack sampling; fire validation still enforces the 200 ms ceiling."""
import math
import secrets
import time

def tick_now():
    return (time.monotonic_ns() * 60 // 1_000_000_000) & 0xffffffff

def uint(value, maximum=0xffffffff):
    return type(value) is int and 0 <= value <= maximum

class RemoteClock:
    def __init__(self, bridge, slot):
        self.bridge, self.slot, self.sample, self.previous = bridge, slot, None, None

    async def begin(self, client):
        if not uint(client):
            raise ValueError("clock tick")
        now = time.monotonic()
        view = await self.bridge.call(self.slot, "1:1", "show")
        token = secrets.token_hex(16)
        self.sample = token, client, view["tick"], view["epoch"], now
        return {"clock": token, "tick": view["tick"], "epoch": view["epoch"]}

    async def finish(self, token, client):
        if self.sample is None or not isinstance(token, str) or not uint(client):
            raise ValueError("clock acknowledgement")
        expected, first, server, epoch, start = self.sample
        self.sample = None
        elapsed, now = time.monotonic() - start, time.monotonic()
        if not secrets.compare_digest(token, expected) or not 0 <= elapsed <= .4 or (client-first) & 0xffffffff > math.ceil(elapsed*60)+2:
            raise ValueError("clock sample expired")
        view = await self.bridge.call(self.slot, "1:1", "show")
        if view["epoch"] != epoch or not server <= view["tick"] <= server+24:
            raise ValueError("clock epoch")
        offset = (((server+view["tick"])//2-client-1+0x80000000) & 0xffffffff)-0x80000000
        if self.previous:
            old, at, server_tick = self.previous
            change = ((offset-old+0x80000000) & 0xffffffff)-0x80000000
            server_drift=view["tick"]-server_tick-round((now-at)*60)
            if abs(change-server_drift) > max(3, int(now-at)+1):
                raise ValueError("clock offset changed too quickly")
        if (await self.bridge.call(self.slot, "1:1", f"sync {offset}")).get("code") != 0:
            raise RuntimeError("clock sync failed")
        self.previous = offset, now, view["tick"]
        return {"synced": True, "epoch": epoch}

def fire_command(message):
    f = message["fire"]
    limits = {"epoch": (1, 0xffffffffffffffff), "tick": (0, 0xffffffff), "lifeEpoch": (1, 0xffffffff),
              "revision": (1, 0xffffffffffffffff), "sequence": (1, 0xffffffff), "event": (1, 0xffffffff),
              "yaw": (-32768, 32767), "pitch": (-16384, 16384)}
    if not isinstance(f, dict) or set(f) != set(limits) or any(type(f[k]) is not int or not a <= f[k] <= b for k, (a,b) in limits.items()):
        raise ValueError("fire intent")
    parts = message["command"].split()
    if len(parts) != 2 or parts[0] != "fire":
        raise ValueError("fire command")
    return "r-fire " + parts[1] + " " + " ".join(str(f[k]) for k in limits)
