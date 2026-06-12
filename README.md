# Multi-Source Snowflake Warehouse (dbt)

An end-to-end analytics warehouse on **Snowflake**, transformed with **dbt** through a
3-layer architecture into a **Kimball star schema**. Data is ingested from three
different source types ? an operational **Postgres** database, **flat files** (clickstream
and marketing spend), and a live **REST API** (FX exchange rates) ? landed raw, then
modeled into tested, analytics-ready fact and dimension tables.

## Architecture
## Stack

| Layer          | Tool                          |
|----------------|-------------------------------|
| Sources        | PostgreSQL, flat files, REST API |
| Warehouse      | Snowflake                     |
| Transformation | dbt (staging -> intermediate -> marts) |
| Ingestion      | Python (psycopg2, write_pandas) |
| Testing        | dbt tests + source freshness  |

## Data model

- **Staging (7 models, views):** one cleaned, typed model per source table.
- **Intermediate (2 models, views):** reusable business logic, including a
  forward-filled daily FX rate table used to convert revenue to local currency.
- **Marts (8 models, tables):** a Kimball star schema ? `fct_order_items`,
  `fct_orders`, `fct_marketing_spend`, `fct_web_events` joined to `dim_customers`,
  `dim_products`, `dim_dates`, `dim_channels` via surrogate keys.

## Data quality

- 61 dbt tests: uniqueness, not-null, accepted values, and fact-to-dimension
  referential integrity.
- A custom singular test reconciling order totals against line-item totals.
- Source freshness monitoring on all sources.

## Running it

```bash
# 1. Generate source data (Postgres + files + API)
python scripts/generate_sources.py

# 2. Load raw sources into Snowflake
python scripts/load_to_snowflake.py

# 3. Build and test the warehouse
cd dbt
dbt deps
dbt build
dbt source freshness
```

Connection details are read from environment variables and `~/.dbt/profiles.yml`
(never committed).

## Roadmap

- Airflow DAGs to orchestrate the extract-load and dbt runs on a schedule.
- Terraform to provision the Snowflake and AWS resources as code.
