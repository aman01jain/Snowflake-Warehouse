-- =============================================================
-- postgres_ddl.sql  —  the operational (OLTP) source database
-- Run this against your LOCAL Postgres, e.g.:
--   createdb ecommerce_src
--   psql -d ecommerce_src -f scripts/postgres_ddl.sql
-- =============================================================

DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders      CASCADE;
DROP TABLE IF EXISTS products    CASCADE;
DROP TABLE IF EXISTS customers   CASCADE;

CREATE TABLE customers (
    customer_id   SERIAL PRIMARY KEY,
    first_name    TEXT        NOT NULL,
    last_name     TEXT        NOT NULL,
    email         TEXT        NOT NULL UNIQUE,
    country       TEXT        NOT NULL,
    created_at    TIMESTAMP   NOT NULL
);

CREATE TABLE products (
    product_id    SERIAL PRIMARY KEY,
    product_name  TEXT        NOT NULL,
    category      TEXT        NOT NULL,
    price_usd     NUMERIC(10,2) NOT NULL,
    created_at    TIMESTAMP   NOT NULL
);

CREATE TABLE orders (
    order_id      SERIAL PRIMARY KEY,
    customer_id   INTEGER     NOT NULL REFERENCES customers(customer_id),
    order_date    TIMESTAMP   NOT NULL,
    status        TEXT        NOT NULL,   -- placed | shipped | delivered | cancelled | returned
    currency      TEXT        NOT NULL    -- USD | EUR | GBP | JPY | CAD
);

CREATE TABLE order_items (
    order_item_id  SERIAL PRIMARY KEY,
    order_id       INTEGER    NOT NULL REFERENCES orders(order_id),
    product_id     INTEGER    NOT NULL REFERENCES products(product_id),
    quantity       INTEGER    NOT NULL,
    unit_price_usd NUMERIC(10,2) NOT NULL
);

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_date     ON orders(order_date);
CREATE INDEX idx_items_order     ON order_items(order_id);
