import datetime
from contextlib import closing
import hashlib
import json
import secrets
import sqlite3
import ssl
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import NameOID
from .common import ROOT

def content_hashes():
    groups = {
        "catalog": ["core/game_catalog*.cpp", "core/craft_catalog.cpp", "core/game_definitions.cpp"],
        "collision": ["core/beam*.cpp", "core/structures.cpp", "core/vehicle*.cpp"],
        "sockets": ["core/weapons.hpp", "core/weapon_assembly.cpp", "assets/style_pack.json"],
    }
    return {key: hashlib.sha256(b"".join(p.read_bytes() for p in sorted({p for pattern in patterns for p in ROOT.glob(pattern)}))).hexdigest()
            for key, patterns in groups.items()}

def certificate():
    key = ec.generate_private_key(ec.SECP256R1())
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "AstraGame local room")])
    now = datetime.datetime.now(datetime.timezone.utc)
    cert = (x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key())
            .serial_number(x509.random_serial_number()).not_valid_before(now - datetime.timedelta(minutes=5))
            .not_valid_after(now + datetime.timedelta(days=3650))
            .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
            .sign(key, hashes.SHA256()))
    return cert.public_bytes(serialization.Encoding.PEM), key.private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption())

class Identity:
    def __init__(self, path):
        self.path = path
        with closing(self.connect()) as db, db:
            db.execute("BEGIN IMMEDIATE")
            db.execute("CREATE TABLE IF NOT EXISTS room_identity(id INTEGER PRIMARY KEY CHECK(id=1), invite TEXT NOT NULL, cert BLOB NOT NULL, key BLOB NOT NULL, content TEXT NOT NULL)")
            db.execute("CREATE TABLE IF NOT EXISTS room_players(slot INTEGER PRIMARY KEY CHECK(slot BETWEEN 2 AND 20), token BLOB UNIQUE NOT NULL CHECK(length(token)=32), name TEXT NOT NULL)")
            row = db.execute("SELECT invite,cert,key,content FROM room_identity WHERE id=1").fetchone()
            if row is None:
                cert, key = certificate()
                row = secrets.token_urlsafe(32), cert, key, json.dumps(content_hashes(), sort_keys=True)
                db.execute("INSERT INTO room_identity VALUES(1,?,?,?,?)", row)
            if json.loads(row[3]) != content_hashes():
                raise ValueError("gameplay content changed; use a new world or an explicit migration")
        self.invite, cert, key, _ = row
        self.content = content_hashes()
        self.fingerprint = hashlib.sha256(ssl.PEM_cert_to_DER_cert(cert.decode())).hexdigest()
        for filename, data in (("room-cert.pem", cert), ("room-key.pem", key)):
            file = path.parent / filename
            file.write_bytes(data)
            file.chmod(0o600)
        self.context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        self.context.minimum_version = ssl.TLSVersion.TLSv1_3
        self.context.load_cert_chain(path.parent / "room-cert.pem", path.parent / "room-key.pem")

    def connect(self):
        db = sqlite3.connect(self.path, timeout=2)
        db.execute("PRAGMA synchronous=FULL")
        db.execute("PRAGMA foreign_keys=ON")
        return db

    def bind(self, invite, token, name, existing=False):
        if not isinstance(invite, str) or not secrets.compare_digest(invite, self.invite):
            raise ValueError("invalid invitation")
        if not isinstance(token, str) or len(token) != 64 or any(c not in "0123456789abcdef" for c in token):
            raise ValueError("invalid resume token")
        if not isinstance(name, str) or not 1 <= len(name) <= 32 or any(ord(c) < 32 for c in name):
            raise ValueError("invalid player name")
        digest = hashlib.sha256(bytes.fromhex(token)).digest()
        with closing(self.connect()) as db, db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("SELECT slot FROM room_players WHERE token=?", (digest,)).fetchone()
            if row:
                return row[0]
            slots = {r[0] for r in db.execute("SELECT slot FROM room_players")}
            slot = next((i for i in range(2, 21) if i not in slots), None)
            if existing or slot is None:
                raise ValueError("room full or unknown identity")
            db.execute("INSERT INTO room_players VALUES(?,?,?)", (slot, digest, name))
            return slot
