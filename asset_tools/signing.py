import base64
from datetime import datetime, timezone
from pathlib import Path
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey
from .common import canonical, digest, read_json

def keygen(private, public):
    key = Ed25519PrivateKey.generate()
    private, public = Path(private), Path(public)
    if private.exists() or public.exists():
        raise ValueError("signing keys already exist")
    private.parent.mkdir(parents=True, exist_ok=True)
    public.parent.mkdir(parents=True, exist_ok=True)
    with private.open("xb") as file:
        file.write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
    private.chmod(0o600)
    with public.open("xb") as file:
        file.write(key.public_key().public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo))

def sign(payload, private):
    key = serialization.load_pem_private_key(Path(private).read_bytes(), password=None)
    if not isinstance(key, Ed25519PrivateKey):
        raise ValueError("Ed25519 signing key required")
    public = key.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
    return {"payload": payload, "keyId": digest(public), "signature": base64.b64encode(key.sign(canonical(payload))).decode()}

def verified(path, trusted):
    envelope = read_json(path)
    key = serialization.load_pem_public_key(Path(trusted).read_bytes())
    if not isinstance(key, Ed25519PublicKey):
        raise ValueError("Ed25519 trust key required")
    public = key.public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
    if envelope["keyId"] != digest(public):
        raise ValueError("untrusted reviewer")
    key.verify(base64.b64decode(envelope["signature"], validate=True), canonical(envelope["payload"]))
    return envelope["payload"]

def approval(kind, subject, reviewer, checks, private, output):
    required = {"lighting", "seams", "clearance", "scale", "licensing"}
    if not reviewer.strip() or not required <= set(checks):
        raise ValueError("human reviewer and all visual/licensing checks required")
    payload = {"kind": kind, "subjectHash": subject, "reviewer": reviewer, "checks": sorted(set(checks)),
               "reviewedAt": datetime.now(timezone.utc).isoformat()}
    Path(output).write_bytes(canonical(sign(payload, private)))
    return payload
