with source as (
    select * from {{ source('s3', 'web_events') }}
),
renamed as (
    select
        event_id,
        session_id,
        customer_id::int               as customer_id,
        lower(event_type)              as event_type,
        page_url,
        event_timestamp::timestamp_ntz as event_at
    from source
)
select * from renamed
