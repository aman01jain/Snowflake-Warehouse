output "warehouse" { value = snowflake_warehouse.tf.name }
output "database"  { value = snowflake_database.prod.name }
output "role"      { value = snowflake_account_role.transformer_prod.name }
