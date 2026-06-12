with source as (
    select * from {{ source('postgres', 'orders') }}
),
renamed as (
    select
        order_id,
        customer_id,
        order_date::timestamp_ntz  as ordered_at,
        cast(order_date as date)   as order_date,
        lower(status)              as order_status,
        upper(currency)            as currency_code
    from source
)
select * from renamed
