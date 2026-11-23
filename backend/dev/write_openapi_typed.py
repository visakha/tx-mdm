"""Write openapi-typed.json to a file on demand (0.9.12).

Run from backend/ with the backend running:
    .venv/bin/python dev/write_openapi_typed.py --url http://localhost:8000 --out FILE

It GETs <url>/openapi-typed.json from the running backend (which reads the live B360 metadata,
read-only) and writes it pretty-printed. Default out: backend/openapi-typed.json (git-ignored).
"""

import argparse
import json
from pathlib import Path

import httpx

DEFAULT_OUT = Path(__file__).resolve().parents[1] / "openapi-typed.json"


def main() -> None:
    parser = argparse.ArgumentParser(description="Save /openapi-typed.json to a file")
    parser.add_argument("--url", default="http://localhost:8000")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    reply = httpx.get(args.url.rstrip("/") + "/openapi-typed.json", timeout=60)
    reply.raise_for_status()
    spec = reply.json()
    args.out.write_text(json.dumps(spec, indent=2, ensure_ascii=True) + "\n", encoding="ascii")
    warnings = spec.get("x-typed-warnings") or []
    print(f"wrote {args.out} ({len(spec.get('components', {}).get('schemas', {}))} schemas)")
    for w in warnings:
        print("warning:", w)


if __name__ == "__main__":
    main()
