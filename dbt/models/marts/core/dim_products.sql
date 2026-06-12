with products as (
    select * from {{ ref('stg_postgres__products') }}
)
select
    {{ dbt_utils.generate_surrogate_key(['product_id']) }} as product_key,
    product_id,
    product_name,
    category,
    list_price_usd,
    created_at
from products
