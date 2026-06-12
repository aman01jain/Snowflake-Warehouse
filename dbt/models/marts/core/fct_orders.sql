-- Grain: one row per order (aggregated from line items).
with items as (
    select * from {{ ref('int_order_items__enriched') }}
),
agg as (
    select
        order_id,
        customer_id,
        order_date,
        order_status,
        currency_code,
        count(*)                 as num_line_items,
        sum(quantity)            as total_quantity,
        sum(gross_amount_usd)    as gross_amount_usd,
        sum(gross_amount_local)  as gross_amount_local
    from items
    group by order_id, customer_id, order_date, order_status, currency_code
)
select
    {{ dbt_utils.generate_surrogate_key(['order_id']) }}    as order_key,
    order_id,
    {{ dbt_utils.generate_surrogate_key(['customer_id']) }} as customer_key,
    to_number(to_char(order_date, 'YYYYMMDD'))              as order_date_key,
    order_status,
    currency_code,
    num_line_items,
    total_quantity,
    gross_amount_usd,
    gross_amount_local
from agg
