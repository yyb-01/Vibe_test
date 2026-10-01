"""Measure native authority + SQLite FULL ACK; this is not the full G.5 content scene."""
import argparse
import asyncio
import json
import platform
import tempfile
import time
from pathlib import Path
from game_launcher.bridge import Bridge

async def measure(args,path):
    bridge=await Bridge.open(path,args.executable);rows=[];views=[];view_bytes=[]
    try:
        for slot in range(2,args.players+1):
            assert (await bridge.call(slot,f"987:{slot}","online 1"))["code"]==0
        for i in range(args.warmup+args.ticks):
            start=time.perf_counter_ns();reply=await bridge.call(0,f"986:{i+1}","tick")
            assert reply["code"]==0,reply
            if i>=args.warmup:rows.append((time.perf_counter_ns()-start)/1e6)
            if i%12==0:
                start=time.perf_counter_ns();view=await bridge.call(1,"1:1","show")
                if i>=args.warmup:views.append((time.perf_counter_ns()-start)/1e6);view_bytes.append(len(json.dumps(view).encode()))
        def summary(values):
            values=sorted(values)
            return {f"p{p}":round(values[max(0,(len(values)*p+99)//100-1)],3) for p in (50,95,99)}|{"max":round(values[-1],3)}
        result={"platform":platform.platform(),"players":args.players,"ticks":args.ticks,"warmup":args.warmup,
                "tickAckMs":summary(rows),"viewMs":summary(views),"maxViewBytes":max(view_bytes),"saveBytes":path.stat().st_size,
                "tickBudgetPassed":summary(rows)["p99"]<=16.67,
                "scope":"seed: 1 vehicle, 8 zombies, 20 inventories, native bridge, SQLite WAL/FULL; no UE/render/network latency matrix or G.5 maximum-content scene"}
        print(json.dumps(result,ensure_ascii=False,indent=2))
        if args.output:
            output=Path(args.output);output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf8")
    finally:assert await bridge.close()

if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument('--players',type=int,choices=(1,20),default=1)
    p.add_argument('--ticks',type=int,default=300);p.add_argument('--warmup',type=int,default=60)
    p.add_argument('--output');p.add_argument('--executable');args=p.parse_args()
    if not 120<=args.ticks<=100000 or not 31<=args.warmup<=10000:p.error('measurement requires ticks 120..100000 and warmup 31..10000')
    base=Path('.build/game-benchmark');base.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(dir=base) as directory:asyncio.run(measure(args,Path(directory)/'world.sqlite3'))
