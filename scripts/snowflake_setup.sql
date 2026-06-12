-- =============================================================
-- snowflake_setup.sql
-- One-time bootstrap. Run this in a Snowflake worksheet as ACCOUNTADMIN.
-- Later, Terraform will manage this same setup as code (Step 6).
-- =============================================================

USE ROLE ACCOUNTADMIN;

-- --- Warehouse (compute) ---
CREATE WAREHOUSE IF NOT EXISTS WH_TRANSFORM
  WAREHOUSE_SIZE = 'XSMALL'      -- smallest = cheapest; fine for this project
  AUTO_SUSPEND   = 60            -- suspend after 60s idle to save credits
  AUTO_RESUME    = TRUE
  INITIALLY_SUSPENDED = TRUE;

-- --- Database + schemas (one per layer) ---
CREATE DATABASE IF NOT EXISTS ECOMMERCE;

CREATE SCHEMA IF NOT EXISTS ECOMMERCE.RAW;          -- landing zone (loaded as-is)
CREATE SCHEMA IF NOT EXISTS ECOMMERCE.STAGING;      -- dbt staging models
CREATE SCHEMA IF NOT EXISTS ECOMMERCE.INTERMEDIATE; -- dbt intermediate models
CREATE SCHEMA IF NOT EXISTS ECOMMERCE.MARTS;        -- dbt marts (facts + dims)

-- --- Role for the pipeline (least-privilege, not ACCOUNTADMIN) ---
CREATE ROLE IF NOT EXISTS TRANSFORMER;

GRANT USAGE   ON WAREHOUSE WH_TRANSFORM TO ROLE TRANSFORMER;
GRANT USAGE   ON DATABASE  ECOMMERCE     TO ROLE TRANSFORMER;
GRANT USAGE   ON ALL SCHEMAS IN DATABASE ECOMMERCE TO ROLE TRANSFORMER;
GRANT CREATE TABLE, CREATE VIEW ON ALL SCHEMAS IN DATABASE ECOMMERCE TO ROLE TRANSFORMER;
-- dbt creates objects, so it also needs rights on future schemas:
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE ECOMMERCE TO ROLE TRANSFORMER;
GRANT ALL   ON FUTURE TABLES  IN DATABASE ECOMMERCE TO ROLE TRANSFORMER;
GRANT ALL   ON FUTURE VIEWS   IN DATABASE ECOMMERCE TO ROLE TRANSFORMER;

-- --- Assign the role to your user (replace MY_USER with your login) ---
-- GRANT ROLE TRANSFORMER TO USER MY_USER;

-- Sanity check
SHOW WAREHOUSES LIKE 'WH_TRANSFORM';
SHOW SCHEMAS IN DATABASE ECOMMERCE;
