-- Singular test: each order's total in fct_orders must equal the sum of its
-- line items in fct_order_items. Passes when this query returns 0 rows.
with line_item_totals as (
    select order_id, round(sum(gross_amount_usd), 2) as items_total
    from {{ ref('fct_order_items') }}
    group by order_id
),
order_totals as (
    select order_id, round(gross_amount_usd, 2) as order_total
    from {{ ref('fct_orders') }}
)
select
    o.order_id,
    o.order_total,
    i.items_total
from order_totals o
join line_item_totals i on o.order_id = i.order_id
where abs(o.order_total - i.items_total) > 0.01
