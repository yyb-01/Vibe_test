import asyncio
import json
import secrets
from .common import ROOT, decode_json

class UI:
    def __init__(self, call, stop, invitation=None):
        self.call, self.stop, self.invitation = call, stop, invitation
        self.token = secrets.token_urlsafe(32)
        self.server = None

    async def open(self, port=0):
        self.server = await asyncio.start_server(self.handle, "127.0.0.1", port, limit=8192)
        self.port = self.server.sockets[0].getsockname()[1]
        return f"http://127.0.0.1:{self.port}/#{self.token}"

    async def handle(self, reader, writer):
        try:
            raw = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), 5)
            rows = raw.decode("ascii").split("\r\n")
            method, path, version = rows[0].split()
            headers = {}
            for row in rows[1:]:
                if not row:
                    continue
                key, value = row.split(":", 1)
                if key.lower() in headers:
                    raise ValueError("duplicate header")
                headers[key.lower()] = value.strip()
            host = f"127.0.0.1:{self.port}"
            if headers.get("host") != host or version != "HTTP/1.1" or "transfer-encoding" in headers:
                raise ValueError("HTTP origin")
            if method == "GET" and path in {"/", "/app.js", "/style.css"}:
                file = "index.html" if path == "/" else path[1:]
                data = (ROOT / "game_ui" / file).read_bytes()
                mime = "text/html; charset=utf-8" if file.endswith("html") else "text/javascript" if file.endswith("js") else "text/css"
            elif method == "POST" and path in {"/command", "/info", "/quit"}:
                if headers.get("origin") != f"http://{host}" or not secrets.compare_digest(headers.get("authorization", ""), "Bearer " + self.token):
                    raise ValueError("UI authorization")
                length = int(headers.get("content-length", "0"))
                if not 0 < length <= 2048:
                    raise ValueError("body limit")
                body = decode_json(await asyncio.wait_for(reader.readexactly(length), 5))
                if path == "/quit":
                    self.stop.set()
                    reply = {"closing": True}
                elif path == "/info":
                    reply = {"invitation": self.invitation}
                else:
                    if not isinstance(body, dict) or set(body) != {"command"}:
                        raise ValueError("UI request")
                    text = body["command"]
                    if not isinstance(text, str) or not text.strip() or len(text) > 1800 or not text.isascii() or any(ord(c) < 32 for c in text) or text.split()[0] in {"tick", "online", "sync", "r-fire"}:
                        raise ValueError("UI command")
                    reply = await self.call(body["command"])
                data, mime = json.dumps(reply, allow_nan=False).encode(), "application/json"
            else:
                raise ValueError("HTTP route")
            writer.write(f"HTTP/1.1 200 OK\r\nContent-Type: {mime}\r\nContent-Length: {len(data)}\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nContent-Security-Policy: default-src 'self'; connect-src 'self'; frame-ancestors 'none'\r\n\r\n".encode() + data)
            await asyncio.wait_for(writer.drain(), 5)
        except (ValueError, OSError, TimeoutError, asyncio.IncompleteReadError, asyncio.LimitOverrunError):
            writer.write(b"HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
        finally:
            writer.close()

    async def close(self):
        self.server.close()
        await self.server.wait_closed()
