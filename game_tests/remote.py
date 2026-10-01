import asyncio
from game_launcher.clock import tick_now

async def checks(client):
    await client.synchronize()
    view=await client.call("show");weapon=view["weapons"][0]
    fields={"epoch":client.epoch,"tick":tick_now(),"lifeEpoch":view["lifeEpoch"],"revision":weapon["revision"],
            "sequence":weapon["inputSeq"]+1,"event":weapon["fireSeq"]+1,"yaw":view["yaw"],"pitch":view["pitch"]}
    for i,changes,code in [(1,{"tick":(fields["tick"]+60)&0xffffffff},1),
                           (2,{"tick":(fields["tick"]-60)&0xffffffff},1),
                           (3,{"revision":fields["revision"]+1},6),(4,{"epoch":client.epoch+1},3)]:
        reply=await client.exchange("commands",{"id":f"777:{i}","command":"fire "+weapon["id"],"fire":fields|changes})
        assert reply["code"]==code,(changes,reply)
    original=client.exchange;ack=None
    async def lose(channel,message):
        nonlocal ack
        reply=await original(channel,message)
        if channel=="commands":ack=reply;raise OSError("test: ACK lost after commit")
        return reply
    client.exchange=lose
    try:
        try:await client.call("fire "+weapon["id"]);raise AssertionError("ACK was not lost")
        except OSError:pass
    finally:client.exchange=original
    assert ack["code"]==0,ack
    assert client.saved["pending"]["fire"]
    await asyncio.sleep(.12)
    again=await client.call("fire "+weapon["id"])
    assert again["code"]==0 and again["sequence"]==ack["sequence"]
    now=await client.call("show");fired=now["weapons"][0]
    assert fired["shots"]==1 and 0<=ack["tick"]-(fired["effectiveQ16"]>>16)<=12
    assert next(i["qty"] for i in now["items"] if i["id"]=="5:10110")==19
    print("PASS remote clock rewind, stale/future/revision/epoch rejection and lost fire ACK replay")
