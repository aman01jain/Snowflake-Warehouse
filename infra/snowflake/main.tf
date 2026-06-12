terraform {
  required_version = ">= 1.5"
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.16"
    }
  }
}

# Authenticates from environment variables:
#   SNOWFLAKE_ORGANIZATION_NAME, SNOWFLAKE_ACCOUNT_NAME,
#   SNOWFLAKE_USER, SNOWFLAKE_PASSWORD, SNOWFLAKE_ROLE (set to ACCOUNTADMIN)
provider "snowflake" {}

# ----- Compute -----
resource "snowflake_warehouse" "tf" {
  name                = "WH_TF"
  warehouse_size      = "XSMALL"
  auto_suspend        = 60
  auto_resume         = true
  initially_suspended = true
  comment             = "Provisioned by Terraform"
}

# ----- A parallel prod database + the four layer schemas (IaC-managed) -----
resource "snowflake_database" "prod" {
  name    = "ECOMMERCE_PROD"
  comment = "Provisioned by Terraform"
}

resource "snowflake_schema" "raw" {
  name     = "RAW"
  database = snowflake_database.prod.name
}
resource "snowflake_schema" "staging" {
  name     = "STAGING"
  database = snowflake_database.prod.name
}
resource "snowflake_schema" "intermediate" {
  name     = "INTERMEDIATE"
  database = snowflake_database.prod.name
}
resource "snowflake_schema" "marts" {
  name     = "MARTS"
  database = snowflake_database.prod.name
}

# ----- Role + grants -----
resource "snowflake_account_role" "transformer_prod" {
  name    = "TRANSFORMER_PROD"
  comment = "Provisioned by Terraform"
}

resource "snowflake_grant_privileges_to_account_role" "warehouse_usage" {
  account_role_name = snowflake_account_role.transformer_prod.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.tf.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "database_usage" {
  account_role_name = snowflake_account_role.transformer_prod.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.prod.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "schema_privileges" {
  account_role_name = snowflake_account_role.transformer_prod.name
  privileges        = ["USAGE", "CREATE TABLE", "CREATE VIEW"]
  on_schema {
    all_schemas_in_database = snowflake_database.prod.name
  }
  depends_on = [
    snowflake_schema.raw,
    snowflake_schema.staging,
    snowflake_schema.intermediate,
    snowflake_schema.marts,
  ]
}

# ----- Grant the role to your user -----
resource "snowflake_grant_account_role" "to_user" {
  role_name = snowflake_account_role.transformer_prod.name
  user_name = var.snowflake_user
}
