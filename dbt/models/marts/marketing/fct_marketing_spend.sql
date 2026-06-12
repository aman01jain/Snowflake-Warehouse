-- Grain: one row per channel per day.
with spend as (
    select * from {{ ref('stg_s3__marketing_spend') }}
)
select
    {{ dbt_utils.generate_surrogate_key(['spend_date', 'channel']) }} as marketing_spend_key,
    {{ dbt_utils.generate_surrogate_key(['channel']) }}               as channel_key,
    to_number(to_char(spend_date, 'YYYYMMDD'))                        as spend_date_key,
    spend_date,
    campaign,
    spend_usd,
    impressions,
    clicks,
    case when clicks > 0 then round(spend_usd / clicks, 2) else 0 end as cost_per_click
from spend
