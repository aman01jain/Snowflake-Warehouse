with source as (
    select * from {{ source('postgres', 'customers') }}
),
renamed as (
    select
        customer_id,
        initcap(first_name)        as first_name,
        initcap(last_name)         as last_name,
        lower(email)               as email,
        upper(country)             as country_code,
        created_at::timestamp_ntz  as created_at
    from source
)
select * from renamed
