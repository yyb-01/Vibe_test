import argparse
from pathlib import Path
from .common import canonical, digest, read_json

def main():
    parser = argparse.ArgumentParser(description="Astra canonical assets: sources remain read-only")
    sub = parser.add_subparsers(dest="command", required=True)
    def input_output(name):
        p = sub.add_parser(name); p.add_argument("input", type=Path); p.add_argument("output", type=Path)
        return p
    p = input_output("normalize"); p.add_argument("--metadata", type=Path, required=True); p.add_argument("--style", type=Path, required=True); p.add_argument("--template", required=True)
    p = input_output("bake"); p.add_argument("--high", type=Path, required=True); p.add_argument("--size", type=int, default=512); p.add_argument("--cage", type=float, default=.01)
    p = input_output("validate"); p.add_argument("--style", type=Path, required=True)
    p = input_output("golden"); p.add_argument("--size", type=int, default=256)
    p = sub.add_parser("keygen"); p.add_argument("private", type=Path); p.add_argument("public", type=Path)
    p = input_output("approve"); p.add_argument("--kind", choices=["asset", "style"], required=True); p.add_argument("--style", type=Path); p.add_argument("--reviewer", required=True); p.add_argument("--checks", nargs="+", required=True); p.add_argument("--key", type=Path, required=True)
    p = input_output("cook")
    for name in ("style", "asset-approval", "style-approval", "trust", "key"):
        p.add_argument("--"+name, type=Path, required=True)
    p = sub.add_parser("verify"); p.add_argument("input", type=Path); p.add_argument("--trust", type=Path, required=True)
    a = parser.parse_args()
    if a.command == "normalize":
        from .normalize import normalize
        result = normalize(a.input, a.metadata, a.style, a.template, a.output)
    elif a.command == "bake":
        from .bake import bake_normal
        from .mesh_io import load_mesh
        result = bake_normal(load_mesh(a.input), load_mesh(a.high), a.output, a.size, a.cage)
        a.output.with_suffix(".bake.json").write_bytes(canonical(result))
    elif a.command == "golden":
        from .golden import golden
        result = golden(a.input, a.output, a.size)
    elif a.command == "validate":
        from .validate import validate
        result = validate(a.input, a.style); a.output.write_bytes(canonical(result))
        if result["status"] != "passed":
            print(canonical(result).decode()); raise SystemExit(1)
    elif a.command == "keygen":
        from .signing import keygen
        keygen(a.private, a.public); result = {"created": True}
    elif a.command == "approve":
        from .signing import approval
        if a.kind == "asset":
            from .validate import validate
            result = validate(a.input, a.style)
            if result["status"] != "passed":
                raise ValueError("validation failed; approval blocked")
            subject = result["contentHash"]
        else:
            subject = digest(canonical(read_json(a.input)))
        result = approval(a.kind, subject, a.reviewer, a.checks, a.key, a.output)
    elif a.command == "cook":
        from .cook import cook
        result = cook(a.input, a.style, a.asset_approval, a.style_approval, a.trust, a.key, a.output)
    else:
        from .cook import verify
        result = verify(a.input, a.trust)
    print(canonical(result).decode())

if __name__ == "__main__":
    main()
