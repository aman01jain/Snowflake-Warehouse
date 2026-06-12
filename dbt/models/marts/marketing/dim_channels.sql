with channels as (
    select distinct channel from {{ ref('stg_s3__marketing_spend') }}
)
select
    {{ dbt_utils.generate_surrogate_key(['channel']) }} as channel_key,
    channel as channel_name
from channels
