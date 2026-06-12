-- Grain: one row per web event (customer_key null for anonymous traffic).
with events as (
    select * from {{ ref('stg_s3__web_events') }}
)
select
    event_id,
    session_id,
    case
        when customer_id is not null
        then {{ dbt_utils.generate_surrogate_key(['customer_id']) }}
    end                                            as customer_key,
    to_number(to_char(event_at::date, 'YYYYMMDD')) as event_date_key,
    event_type,
    page_url,
    event_at
from events
