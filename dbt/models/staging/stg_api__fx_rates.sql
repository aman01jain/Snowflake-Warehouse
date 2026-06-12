with source as (
    select * from {{ source('api', 'fx_rates') }}
),
renamed as (
    select
        rate_date::date        as rate_date,
        upper(base_currency)   as base_currency,
        upper(currency)        as quote_currency,
        rate_to_usd::float     as rate_to_usd
    from source
)
select * from renamed
