with customers as (
    select * from {{ ref('stg_postgres__customers') }}
)
select
    {{ dbt_utils.generate_surrogate_key(['customer_id']) }} as customer_key,
    customer_id,
    first_name,
    last_name,
    first_name || ' ' || last_name as full_name,
    email,
    country_code,
    created_at
from customers
