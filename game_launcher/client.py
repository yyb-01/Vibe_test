import asyncio
import hashlib
import secrets
import ssl
import time
from urllib.parse import urlparse, parse_qs
from .common import LIMIT, PROTOCOL, atomic_json, decode_json, receive, send
from .identity import content_hashes
from .clock import tick_now

class Client:
    def __init__(self, invitation, path, name="Player"):
        link = urlparse(invitation)
        values = parse_qs(link.query, strict_parsing=True)
        if link.scheme != "astra" or not link.hostname or not link.port or link.username or link.password or set(values) != {"invite", "cert"} or any(len(v)!=1 for v in values.values()):
            raise ValueError("invalid invitation")
        self.host, self.port = link.hostname, link.port
        self.invite, self.fingerprint = values["invite"][0], values["cert"][0]
        self.path, self.name, self.channels = path, name, {}
        self.saved = decode_json(path.read_bytes()) if path.exists() else {
            "resume": secrets.token_hex(32), "nonce": secrets.randbits(62) | 1, "sequence": 0, "pending": None}
        atomic_json(path, self.saved)
        self.lock = asyncio.Lock()
        self.view, self.clock_at, self.epoch = None, 0, None

    async def connect(self, channel):
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.minimum_version = ssl.TLSVersion.TLSv1_3
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE  # Trust comes from the invitation's exact certificate pin.
        reader, writer = await asyncio.wait_for(asyncio.open_connection(self.host, self.port, ssl=context,
                                                                      server_hostname=self.host), 5)
        cert = writer.get_extra_info("ssl_object").getpeercert(binary_form=True)
        if not secrets.compare_digest(hashlib.sha256(cert).hexdigest(), self.fingerprint):
            writer.close()
            raise ValueError("certificate pin mismatch")
        await send(writer, {"protocol": PROTOCOL, "content": content_hashes(), "invite": self.invite,
                            "resume": self.saved["resume"], "name": self.name, "channel": channel})
        hello = await receive(reader)
        if not isinstance(hello,dict) or set(hello)!={"joined","slot","protocol"} or hello["joined"] is not True or type(hello["slot"]) is not int or not 2<=hello["slot"]<=20 or hello["protocol"]!=PROTOCOL:
            writer.close()
            raise ValueError("room admission failed")
        self.channels[channel] = reader, writer
        if channel == "commands":
            await self.synchronize()

    async def synchronize(self):
        reader,writer=self.channels["commands"]
        await send(writer,{"ping":tick_now()})
        sample=await receive(reader)
        await send(writer,{"clock":sample["clock"],"client":tick_now()})
        result=await receive(reader)
        if result.get("synced") is not True:raise ValueError("clock sync failed")
        self.epoch,self.clock_at=result["epoch"],time.monotonic()

    async def exchange(self, channel, message):
        for attempt in range(2):
            try:
                if channel not in self.channels:
                    if channel == "view" and "commands" not in self.channels:
                        await self.connect("commands")
                    await self.connect(channel)
                reader, writer = self.channels[channel]
                await send(writer, message)
                return await receive(reader, LIMIT)
            except (OSError, asyncio.IncompleteReadError, TimeoutError):
                old = self.channels.pop(channel, None)
                if old:
                    old[1].close()
                if attempt:
                    raise

    async def call(self, text):
        if not isinstance(text,str) or not text.strip():raise ValueError("empty command")
        async with self.lock:
            if text == "show":
                self.view=await self.exchange("view", {"id": "1:1", "command": "show"})
                return self.view
            if self.saved["pending"] and self.saved["pending"]["command"] != text:
                return {"code": 16, "pending": self.saved["pending"]["command"]}
            if not self.saved["pending"]:
                fire=None
                if text.split()[0]=="fire":
                    occurred=tick_now()
                    if "commands" not in self.channels:await self.connect("commands")
                    await self.synchronize()
                    if not self.view:self.view=await self.exchange("view",{"id":"1:1","command":"show"})
                    parts=text.split()
                    if len(parts)!=2:raise ValueError("fire command")
                    weapon=next((w for w in self.view["weapons"] if w["id"]==parts[1]),None)
                    if weapon is None:return {"code":2}
                    fire={"epoch":self.epoch,"tick":occurred,"lifeEpoch":self.view["lifeEpoch"],"revision":weapon["revision"],
                          "sequence":(weapon["inputSeq"]+1)&0xffffffff,"event":(weapon["fireSeq"]+1)&0xffffffff,
                          "yaw":self.view["yaw"],"pitch":self.view["pitch"]}
                self.saved["sequence"] += 1
                self.saved["pending"] = {"id": f'{self.saved["nonce"]}:{self.saved["sequence"]}', "command": text}
                if fire:self.saved["pending"]["fire"]=fire
                atomic_json(self.path, self.saved)
            reply = await self.exchange("commands", self.saved["pending"])
            if reply.get("code") not in {15, 16, 17}:
                self.saved["pending"] = None
                atomic_json(self.path, self.saved)
            return reply

    async def close(self):
        for _, writer in self.channels.values():
            writer.close()
            try:
                await asyncio.wait_for(writer.wait_closed(),5)
            except (OSError,TimeoutError):
                pass
        self.channels.clear()
