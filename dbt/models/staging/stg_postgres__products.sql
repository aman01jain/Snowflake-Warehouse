with source as (
    select * from {{ source('postgres', 'products') }}
),
renamed as (
    select
        product_id,
        product_name,
        category,
        price_usd::number(10,2)    as list_price_usd,
        created_at::timestamp_ntz  as created_at
    from source
)
select * from renamed
