"""
generate_sources.py  —  creates realistic data for all THREE sources.

  1. Postgres (OLTP)  -> customers, products, orders, order_items
  2. S3 files         -> data/sample/web_events.csv, marketing_spend.csv
  3. REST API         -> data/sample/fx_rates.json  (Frankfurter, ECB rates)

Usage:
    # local Postgres connection comes from env vars (with sane defaults)
    export PGHOST=localhost PGPORT=5432 PGDATABASE=ecommerce_src PGUSER=$USER
    python scripts/generate_sources.py

Re-running is safe: it TRUNCATEs the Postgres tables first and overwrites files.
"""
import csv
import json
import os
import random
from datetime import datetime, timedelta, date
from pathlib import Path

from faker import Faker

fake = Faker()
Faker.seed(42)
random.seed(42)

# ---- knobs (turn these up to grow the dataset) ----
N_CUSTOMERS = 800
N_PRODUCTS = 60
N_ORDERS = 6000
N_WEB_EVENTS = 25000
START = datetime(2025, 1, 1)
END = datetime(2026, 1, 1)

OUT_DIR = Path(__file__).resolve().parent.parent / "data" / "sample"
OUT_DIR.mkdir(parents=True, exist_ok=True)

CURRENCIES = ["USD", "EUR", "GBP", "JPY", "CAD"]
COUNTRIES = ["US", "GB", "DE", "FR", "CA", "JP", "AU"]
CATEGORIES = ["Electronics", "Home", "Apparel", "Beauty", "Sports", "Toys"]
ORDER_STATUS = ["placed", "shipped", "delivered", "cancelled", "returned"]
EVENT_TYPES = ["page_view", "add_to_cart", "checkout", "search", "product_view"]
CHANNELS = ["google_ads", "meta", "email", "organic", "affiliate"]


def _rand_dt(start, end):
    delta = end - start
    return start + timedelta(seconds=random.randint(0, int(delta.total_seconds())))


# ---------- generation (pure, testable) ----------
def gen_customers(n):
    rows = []
    for cid in range(1, n + 1):
        first, last = fake.first_name(), fake.last_name()
        rows.append({
            "customer_id": cid,
            "first_name": first,
            "last_name": last,
            "email": f"{first.lower()}.{last.lower()}{cid}@example.com",
            "country": random.choice(COUNTRIES),
            "created_at": _rand_dt(START, END),
        })
    return rows


def gen_products(n):
    rows = []
    for pid in range(1, n + 1):
        rows.append({
            "product_id": pid,
            "product_name": fake.catch_phrase()[:60],
            "category": random.choice(CATEGORIES),
            "price_usd": round(random.uniform(5, 500), 2),
            "created_at": _rand_dt(START, END),
        })
    return rows


def gen_orders(n, n_customers):
    rows = []
    for oid in range(1, n + 1):
        rows.append({
            "order_id": oid,
            "customer_id": random.randint(1, n_customers),
            "order_date": _rand_dt(START, END),
            # weight toward completed orders, some cancelled/returned
            "status": random.choices(ORDER_STATUS, weights=[10, 20, 55, 8, 7])[0],
            "currency": random.choices(CURRENCIES, weights=[55, 20, 12, 8, 5])[0],
        })
    return rows


def gen_order_items(orders, products):
    rows = []
    oiid = 1
    price_by_pid = {p["product_id"]: p["price_usd"] for p in products}
    for o in orders:
        for _ in range(random.randint(1, 5)):
            pid = random.randint(1, len(products))
            rows.append({
                "order_item_id": oiid,
                "order_id": o["order_id"],
                "product_id": pid,
                "quantity": random.randint(1, 4),
                "unit_price_usd": price_by_pid[pid],
            })
            oiid += 1
    return rows


def gen_web_events(n, n_customers):
    rows = []
    for eid in range(1, n + 1):
        # ~30% anonymous (no customer_id) -> realistic clickstream
        cust = random.randint(1, n_customers) if random.random() > 0.3 else ""
        rows.append({
            "event_id": eid,
            "session_id": fake.uuid4(),
            "customer_id": cust,
            "event_type": random.choices(EVENT_TYPES, weights=[50, 15, 8, 12, 15])[0],
            "page_url": f"/p/{random.randint(1, N_PRODUCTS)}",
            "event_timestamp": _rand_dt(START, END).isoformat(),
        })
    return rows


def gen_marketing_spend():
    rows = []
    d = START.date()
    while d < END.date():
        for ch in CHANNELS:
            if ch == "organic":
                spend, imps = 0.0, random.randint(500, 5000)
            else:
                spend = round(random.uniform(50, 2000), 2)
                imps = random.randint(1000, 50000)
            clicks = int(imps * random.uniform(0.005, 0.05))
            rows.append({
                "spend_date": d.isoformat(),
                "channel": ch,
                "campaign": f"{ch}_{d.strftime('%Y%m')}",
                "spend_usd": spend,
                "impressions": imps,
                "clicks": clicks,
            })
        d += timedelta(days=1)
    return rows


# ---------- file outputs (S3 stand-in) ----------
def write_csv(path, rows):
    if not rows:
        return
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print(f"  wrote {len(rows):>6} rows -> {path.name}")


# ---------- REST API source ----------
def fetch_fx_rates(path):
    """Pull a daily USD-based rate time series from Frankfurter (no key)."""
    import urllib.request
    # Try the current v2 endpoint first, then the legacy range URL as backup.
    urls = [
        "https://api.frankfurter.dev/v2/rates"
        "?from=2025-01-01&to=2026-01-01&base=USD&quotes=EUR,GBP,JPY,CAD",
        "https://api.frankfurter.app/2025-01-01..2026-01-01"
        "?from=USD&to=EUR,GBP,JPY,CAD",
    ]
    try:
        payload, used = None, None
        for url in urls:
            try:
                with urllib.request.urlopen(url, timeout=30) as r:
                    payload = json.load(r)
                used = url
                break
            except Exception:
                continue
        if payload is None:
            raise RuntimeError("both Frankfurter endpoints failed")
        with open(path, "w") as f:
            json.dump(payload, f, indent=2)
        n = len(payload.get("rates", {}))
        print(f"  fetched {n} daily FX snapshots -> {path.name}  ({used.split('?')[0]})")
    except Exception as e:  # network/endpoint changed -> static fallback so you're not blocked
        print(f"  [warn] FX API failed ({e}); writing static fallback rates")
        fallback = {
            "base": "USD", "start_date": "2025-01-01", "end_date": "2026-01-01",
            "rates": {"2025-01-01": {"EUR": 0.92, "GBP": 0.79, "JPY": 157.0, "CAD": 1.44}},
        }
        with open(path, "w") as f:
            json.dump(fallback, f, indent=2)


# ---------- Postgres load ----------
def load_postgres(customers, products, orders, order_items):
    import psycopg2
    from psycopg2.extras import execute_values

    conn = psycopg2.connect(
        host=os.getenv("PGHOST", "localhost"),
        port=os.getenv("PGPORT", "5432"),
        dbname=os.getenv("PGDATABASE", "ecommerce_src"),
        user=os.getenv("PGUSER", os.getenv("USER", "postgres")),
        password=os.getenv("PGPASSWORD", ""),
    )
    conn.autocommit = False
    cur = conn.cursor()
    cur.execute("TRUNCATE order_items, orders, products, customers RESTART IDENTITY CASCADE;")

    execute_values(cur,
        "INSERT INTO customers (customer_id, first_name, last_name, email, country, created_at) VALUES %s",
        [(c["customer_id"], c["first_name"], c["last_name"], c["email"], c["country"], c["created_at"]) for c in customers])
    execute_values(cur,
        "INSERT INTO products (product_id, product_name, category, price_usd, created_at) VALUES %s",
        [(p["product_id"], p["product_name"], p["category"], p["price_usd"], p["created_at"]) for p in products])
    execute_values(cur,
        "INSERT INTO orders (order_id, customer_id, order_date, status, currency) VALUES %s",
        [(o["order_id"], o["customer_id"], o["order_date"], o["status"], o["currency"]) for o in orders])
    execute_values(cur,
        "INSERT INTO order_items (order_item_id, order_id, product_id, quantity, unit_price_usd) VALUES %s",
        [(i["order_item_id"], i["order_id"], i["product_id"], i["quantity"], i["unit_price_usd"]) for i in order_items])

    conn.commit()
    cur.close()
    conn.close()
    print(f"  loaded Postgres: {len(customers)} customers, {len(products)} products, "
          f"{len(orders)} orders, {len(order_items)} order_items")


def main():
    print("Generating source data...")
    customers = gen_customers(N_CUSTOMERS)
    products = gen_products(N_PRODUCTS)
    orders = gen_orders(N_ORDERS, N_CUSTOMERS)
    order_items = gen_order_items(orders, products)
    web_events = gen_web_events(N_WEB_EVENTS, N_CUSTOMERS)
    marketing = gen_marketing_spend()

    print("[1/3] Postgres (OLTP)")
    load_postgres(customers, products, orders, order_items)

    print("[2/3] S3 files")
    write_csv(OUT_DIR / "web_events.csv", web_events)
    write_csv(OUT_DIR / "marketing_spend.csv", marketing)

    print("[3/3] REST API")
    fetch_fx_rates(OUT_DIR / "fx_rates.json")

    print("Done.")


if __name__ == "__main__":
    main()
