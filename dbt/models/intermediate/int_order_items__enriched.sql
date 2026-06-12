-- One row per order line item, with order context and USD + local-currency amounts.
with order_items as (
    select * from {{ ref('stg_postgres__order_items') }}
),
orders as (
    select * from {{ ref('stg_postgres__orders') }}
),
fx as (
    select * from {{ ref('int_fx__daily_rates') }}
),
joined as (
    select
        oi.order_item_id,
        oi.order_id,
        oi.product_id,
        o.customer_id,
        o.order_date,
        o.ordered_at,
        o.order_status,
        o.currency_code,
        oi.quantity,
        oi.unit_price_usd,
        round(oi.quantity * oi.unit_price_usd, 2) as gross_amount_usd
    from order_items oi
    inner join orders o on oi.order_id = o.order_id
),
with_fx as (
    select
        j.*,
        coalesce(fx.rate_to_usd, 1.0)                              as fx_rate,
        round(j.gross_amount_usd * coalesce(fx.rate_to_usd, 1.0), 2) as gross_amount_local
    from joined j
    left join fx
        on fx.rate_date = j.order_date
       and fx.currency  = j.currency_code
)
select * from with_fx
