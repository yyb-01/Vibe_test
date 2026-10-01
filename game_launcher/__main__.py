import argparse
import asyncio
import hashlib
import os
import webbrowser
from pathlib import Path
from .bridge import Bridge
from .client import Client
from .common import world_path
from .identity import Identity
from .local import LocalClient
from .room import Room
from .ui import UI

async def run(args):
    stop, room, bridge, client, task = asyncio.Event(), None, None, None, None
    try:
        if args.mode == "join":
            if not args.invitation:
                raise ValueError("join requires --invitation")
            base = Path(args.test_root) if args.test_root else Path(os.environ["LOCALAPPDATA"]) / "AstraGame" / "Clients"
            identity = hashlib.sha256(args.invitation.encode()).hexdigest()[:32]
            client = Client(args.invitation, base / (identity + ".json"), args.name)
            await client.connect("commands")
            call, invitation = client.call, None
        else:
            path = world_path(args.world, args.test_root)
            bridge = await Bridge.open(path)
            call = LocalClient(bridge, path.parent / "local-commands.json").call
            invitation = None
            if args.mode == "host":
                identity = Identity(path)
                room = Room(bridge, identity)
                port = await room.open(args.bind, args.port)
                invitation = room.invitation(args.address, port, args.world)
            task = asyncio.create_task(bridge.ticks(stop))
        ui = UI(call, stop, invitation)
        url = await ui.open(args.ui_port)
        print(url, flush=True)
        if not args.no_browser:
            webbrowser.open(url)
        stopped = asyncio.create_task(stop.wait())
        waiters = [stopped] + ([task] if task else [])
        done, _ = await asyncio.wait(waiters, return_when=asyncio.FIRST_COMPLETED)
        if task in done:
            task.result()
        await ui.close()
    finally:
        stop.set()
        if room:
            await room.close()
        if task:
            await asyncio.gather(task, return_exceptions=True)
        if client:
            await client.close()
        if bridge and not await bridge.close():
            raise RuntimeError("save shutdown incomplete; the database is preserved")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["solo", "host", "join"], default="solo")
    parser.add_argument("--world", default="survival")
    parser.add_argument("--name", default="Player")
    parser.add_argument("--invitation")
    parser.add_argument("--bind", default="0.0.0.0")
    parser.add_argument("--address", default="127.0.0.1", help="address placed in the invitation")
    parser.add_argument("--port", type=int, default=7777)
    parser.add_argument("--ui-port", type=int, default=0)
    parser.add_argument("--test-root", help=argparse.SUPPRESS)
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()
    try:
        asyncio.run(run(args))
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()
