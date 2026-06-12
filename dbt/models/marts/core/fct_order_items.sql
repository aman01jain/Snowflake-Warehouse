-- Grain: one row per order line item (the core transactional fact).
with items as (
    select * from {{ ref('int_order_items__enriched') }}
)
select
    {{ dbt_utils.generate_surrogate_key(['order_item_id']) }} as order_item_key,
    order_item_id,
    order_id,
    {{ dbt_utils.generate_surrogate_key(['customer_id']) }}   as customer_key,
    {{ dbt_utils.generate_surrogate_key(['product_id']) }}    as product_key,
    to_number(to_char(order_date, 'YYYYMMDD'))                as order_date_key,
    order_status,
    currency_code,
    quantity,
    unit_price_usd,
    gross_amount_usd,
    fx_rate,
    gross_amount_local
from items
