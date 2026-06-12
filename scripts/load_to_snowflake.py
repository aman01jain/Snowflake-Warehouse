"""
load_to_snowflake.py  —  lands all three sources into the Snowflake RAW schema.

This is the "EL" (extract + load) of the pipeline, before dbt does the "T".
Each source is loaded AS-IS into RAW (no transformation yet):
    Postgres  -> RAW.CUSTOMERS, RAW.PRODUCTS, RAW.ORDERS, RAW.ORDER_ITEMS
    S3 files  -> RAW.WEB_EVENTS, RAW.MARKETING_SPEND
    REST API  -> RAW.FX_RATES   (flattened from the nested JSON)

Connection comes from environment variables:
    Snowflake: SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PASSWORD
    Postgres:  PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD  (same as before)

Run:
    python scripts\\load_to_snowflake.py
Re-running is safe: every table is loaded with overwrite=True.
"""
import json
import os
from pathlib import Path

import pandas as pd
import psycopg2
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas

SAMPLE_DIR = Path(__file__).resolve().parent.parent / "data" / "sample"
PG_TABLES = ["customers", "products", "orders", "order_items"]


def snowflake_conn():
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        role="TRANSFORMER",
        warehouse="WH_TRANSFORM",
        database="ECOMMERCE",
        schema="RAW",
    )


def postgres_conn():
    return psycopg2.connect(
        host=os.getenv("PGHOST", "localhost"),
        port=os.getenv("PGPORT", "5432"),
        dbname=os.getenv("PGDATABASE", "ecommerce_src"),
        user=os.getenv("PGUSER", "postgres"),
        password=os.getenv("PGPASSWORD", ""),
    )


def land(sf, df, table):
    """Upper-case columns (so Snowflake treats them as normal identifiers) and load."""
    df.columns = [c.upper() for c in df.columns]
    # Land datetimes as ISO text in RAW; staging casts them to real types.
    # (Avoids write_pandas inferring an un-castable numeric type for dates.)
    for col in df.columns:
        if pd.api.types.is_datetime64_any_dtype(df[col]):
            df[col] = df[col].dt.strftime("%Y-%m-%d %H:%M:%S")
    # Stamp each row with load time so dbt source freshness can be measured.
    df["_LOADED_AT"] = pd.Timestamp.utcnow().strftime("%Y-%m-%d %H:%M:%S")
    ok, _, nrows, _ = write_pandas(
        sf, df, table, database="ECOMMERCE", schema="RAW",
        auto_create_table=True, overwrite=True,
    )
    status = "OK " if ok else "ERR"
    print(f"  [{status}] RAW.{table:<16} {nrows:>6} rows")


def flatten_fx(path):
    """Turn {'rates': {date: {CUR: rate}}} into tidy rows."""
    payload = json.loads(Path(path).read_text())
    base = payload.get("base", "USD")
    rows = []
    for rate_date, by_cur in payload.get("rates", {}).items():
        for currency, rate in by_cur.items():
            rows.append({
                "rate_date": rate_date,
                "base_currency": base,
                "currency": currency,
                "rate_to_usd": rate,
            })
    return pd.DataFrame(rows)


def main():
    print("Loading sources into Snowflake RAW...")
    sf = snowflake_conn()
    try:
        # 1. Postgres OLTP tables
        print("[1/3] Postgres -> RAW")
        pg = postgres_conn()
        try:
            for t in PG_TABLES:
                cur = pg.cursor()
                cur.execute(f"SELECT * FROM {t}")
                cols = [d[0] for d in cur.description]
                df = pd.DataFrame(cur.fetchall(), columns=cols)
                cur.close()
                land(sf, df, t.upper())
        finally:
            pg.close()

        # 2. S3 / flat files
        print("[2/3] Files -> RAW")
        land(sf, pd.read_csv(SAMPLE_DIR / "web_events.csv"), "WEB_EVENTS")
        land(sf, pd.read_csv(SAMPLE_DIR / "marketing_spend.csv"), "MARKETING_SPEND")

        # 3. REST API (flattened)
        print("[3/3] FX API -> RAW")
        land(sf, flatten_fx(SAMPLE_DIR / "fx_rates.json"), "FX_RATES")

        print("Done. Check ECOMMERCE.RAW in Snowflake.")
    finally:
        sf.close()


if __name__ == "__main__":
    main()
