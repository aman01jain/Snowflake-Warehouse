with source as (
    select * from {{ source('s3', 'marketing_spend') }}
),
renamed as (
    select
        spend_date::date          as spend_date,
        lower(channel)            as channel,
        campaign,
        spend_usd::number(12,2)   as spend_usd,
        impressions::int          as impressions,
        clicks::int               as clicks
    from source
)
select * from renamed
