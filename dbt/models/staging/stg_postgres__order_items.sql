with source as (
    select * from {{ source('postgres', 'order_items') }}
),
renamed as (
    select
        order_item_id,
        order_id,
        product_id,
        quantity::int                 as quantity,
        unit_price_usd::number(10,2)  as unit_price_usd
    from source
)
select * from renamed
