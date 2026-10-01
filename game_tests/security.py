import asyncio
import json
from game_launcher.ui import UI
from game_launcher.clock import RemoteClock, fire_command

async def checks():
    calls=[]
    async def call(text):calls.append(text);return {"code":0}
    ui=UI(call,asyncio.Event())
    await ui.open()
    async def post(body,origin=True,auth=True,path="/command",extra=""):
        reader,writer=await asyncio.open_connection("127.0.0.1",ui.port)
        headers=f"POST {path} HTTP/1.1\r\nHost: 127.0.0.1:{ui.port}\r\nContent-Length: {len(body)}\r\n"+extra
        if origin:headers+=f"Origin: http://127.0.0.1:{ui.port}\r\n"
        if auth:headers+=f"Authorization: Bearer {ui.token}\r\n"
        writer.write(headers.encode()+b"\r\n"+body);await writer.drain()
        reply=await reader.read();writer.close();await writer.wait_closed();return reply
    try:
        valid=b'{"command":"show"}'
        for body,kwargs in [(valid,{"origin":False}),(valid,{"auth":False}),
                            (valid,{"path":"/../world.sqlite3"}),(valid,{"extra":"Content-Length: 1\r\n"}),
                            (b'{"command":"show","command":"tick"}',{}),
                            (b'{"command":NaN}',{}),*( (json.dumps({"command":v}).encode(),{}) for v in ("tick","online 1","sync 0","r-fire 5:1"))]:
            assert (await post(body,**kwargs)).startswith(b"HTTP/1.1 400")
        assert not calls
        result=await post(valid);assert result.startswith(b"HTTP/1.1 200") and b"frame-ancestors 'none'" in result and calls==["show"]
    finally:await ui.close()
    class Bridge:
        async def call(self,slot,nonce,text):return {"code":0,"tick":10,"epoch":1}
    clock=RemoteClock(Bridge(),2);sample=await clock.begin(123)
    assert (await clock.finish(sample["clock"],124))["synced"]
    try:await clock.finish(sample["clock"],124);raise AssertionError("replayed clock")
    except ValueError:pass
    sample=await clock.begin(125)
    try:await clock.finish("0"*32,126);raise AssertionError("forged clock")
    except ValueError:pass
    intent={"epoch":1,"tick":1,"lifeEpoch":1,"revision":1,"sequence":1,"event":1,"yaw":0,"pitch":0}
    assert fire_command({"command":"fire 5:1","fire":intent}).startswith("r-fire 5:1 1 1")
    for key in intent:
        bad=intent|{key:True}
        try:fire_command({"command":"fire 5:1","fire":bad});raise AssertionError("boolean fire field")
        except ValueError:pass
    print("PASS local HTTP origin, bearer, framing, private-command and authenticated clock guards")

if __name__=="__main__":asyncio.run(checks())
