"""
fetch_fx.py  —  standalone, debuggable FX-rate fetcher (the REST API source).

Run it on its own:
    python scripts\\fetch_fx.py

It fixes the two usual Windows failure causes:
  * Cloudflare blocking Python's default user-agent  -> we send a browser UA
  * SSL cert verification on Windows                 -> we use certifi if present
If it STILL fails, it prints the real per-endpoint error so we know the cause.
On success it writes data/sample/fx_rates.json (overwriting the static fallback).
"""
import json
import ssl
import urllib.request
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "data" / "sample" / "fx_rates.json"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/124.0 Safari/537.36",
    "Accept": "application/json",
}

# Ordered best-effort: a full-year time series first, then a single "latest"
# snapshot as a last resort so we still get a real live pull from the API.
URLS = [
    "https://api.frankfurter.dev/v2/rates?from=2025-01-01&to=2026-01-01&base=USD&quotes=EUR,GBP,JPY,CAD",
    "https://api.frankfurter.app/2025-01-01..2026-01-01?from=USD&to=EUR,GBP,JPY,CAD",
    "https://api.frankfurter.dev/v2/rates?base=USD&quotes=EUR,GBP,JPY,CAD",
    "https://api.frankfurter.app/latest?from=USD&to=EUR,GBP,JPY,CAD",
]


def build_ssl_context():
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except Exception:
        return ssl.create_default_context()


def main():
    ctx = build_ssl_context()
    errors = []
    for url in URLS:
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=30, context=ctx) as r:
                payload = json.load(r)
            OUT.parent.mkdir(parents=True, exist_ok=True)
            with open(OUT, "w") as f:
                json.dump(payload, f, indent=2)
            n = len(payload.get("rates", {})) or 1
            print(f"SUCCESS: pulled {n} FX snapshot(s) from {url.split('?')[0]}")
            print(f"  saved -> {OUT}")
            sample = list(payload.get("rates", {}).items())[:1] or [("(latest)", payload.get("rates"))]
            print(f"  sample: {sample}")
            return
        except Exception as e:
            errors.append(f"{url.split('?')[0]} -> {type(e).__name__}: {e}")

    print("FAILED on every endpoint. Real errors:")
    for er in errors:
        print("   -", er)
    print("\nPaste these errors back and we'll pick the right fix.")


if __name__ == "__main__":
    main()
