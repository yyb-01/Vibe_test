import asyncio
import secrets
import sqlite3
import tempfile
from contextlib import closing
from pathlib import Path
from game_launcher.bridge import Bridge
from game_launcher.client import Client
from game_launcher.identity import Identity
from game_launcher.room import Room

async def checks(root,executable=None):
    from .security import checks as security_checks
    from .remote import checks as remote_checks
    await security_checks()
    path = root / "world.sqlite3"
    bridge = await Bridge.open(path,executable)
    clients, room = [], None
    stop=asyncio.Event();ticker=None
    try:
        for n in range(1, 5):
            assert (await bridge.call(0, f"99:{n}", "tick"))["code"] == 0
        first = await bridge.call(1, "88:1", "consume 5:10018")
        assert first["code"] == 0
        assert await bridge.call(1, "88:1", "consume 5:10018") == first
        assert (await bridge.call(1, "88:1", "consume 5:10019"))["code"] == 5
        for n in range(1, 36):
            assert (await bridge.call(0, f"98:{n}", "tick"))["code"] == 0
            assert (await bridge.call(1, f"90:{n}", "aim 0 0"))["code"] == 0
        assert (await bridge.call(1, "90:1", "aim 0 0"))["code"] == 4
        ticker=asyncio.create_task(bridge.ticks(stop))
        identity = Identity(path)
        room = Room(bridge, identity)
        port = await room.open("127.0.0.1", 0)
        invite = room.invitation("127.0.0.1", port, "test")
        for n in range(19):
            client = Client(invite, root / f"client{n}.json")
            await client.connect("commands")
            clients.append(client)
        await remote_checks(clients[0])
        assert len({identity.bind(identity.invite, c.saved["resume"], "Player") for c in clients}) == 19
        extra = Client(invite, root / "extra.json")
        try:
            await extra.connect("commands")
            raise AssertionError("20th remote participant admitted")
        except asyncio.IncompleteReadError:
            pass
        view = await clients[0].call("show")
        assert view["actor"] == "5:1001" and view["bag"] == "5:2001"
        assert all(i["id"] != "5:10018" for i in view["items"])
        assert "gameplay" not in str(view) and "resume" not in str(view)
        assert (await clients[0].call("consume 5:10018"))["code"] == 2
        own = await clients[0].call("consume 5:10118")
        assert own["code"] == 0
        await clients[0].close()
        reconnect = Client(invite, root / "client0.json")
        await reconnect.connect("commands")
        assert (await reconnect.call("show"))["actor"] == "5:1001"
        await reconnect.close()
        bad_pin = Client(invite.replace(identity.fingerprint, "0" * 64), root / "badpin.json")
        try:
            await bad_pin.connect("commands")
            raise AssertionError("invalid TLS certificate admitted")
        except ValueError:
            pass
        async with asyncio.timeout(5):
            try:
                await clients[1].call("tick")
                raise AssertionError("remote simulation command admitted")
            except asyncio.IncompleteReadError:
                pass
    finally:
        stop.set()
        if ticker:await ticker
        for client in clients:
            await client.close()
        if room:
            await room.close()
        assert await bridge.close()
    bridge = await Bridge.open(path,executable)
    try:
        assert (await bridge.call(1, "88:1", "consume 5:10018"))["sequence"] == first["sequence"]
        view = await bridge.call(1, "1:1", "show")
        assert next(i["qty"] for i in view["items"] if i["id"] == "5:10018") == 2
        acknowledged = await bridge.call(1, "88:2", "consume 5:10018")
        assert acknowledged["code"] == 0
        bridge.process.kill()
        await bridge.process.wait()
    finally:
        if bridge.process.returncode is None:
            await bridge.close()
    bridge = await Bridge.open(path,executable)
    try:
        assert (await bridge.call(1, "88:2", "consume 5:10018"))["sequence"] == acknowledged["sequence"]
        view = await bridge.call(1, "1:1", "show")
        assert next(i["qty"] for i in view["items"] if i["id"] == "5:10018") == 1
    finally:
        assert await bridge.close()
    with closing(sqlite3.connect(path)) as db:
        assert db.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
    print("PASS native SQLite restart, crash ACK, TLS 20-player admission, privacy, identity and replay")

if __name__ == "__main__":
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--executable');args=parser.parse_args()
    base = Path(".build/native-tests")
    base.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=base) as directory:
        asyncio.run(checks(Path(directory),args.executable))
