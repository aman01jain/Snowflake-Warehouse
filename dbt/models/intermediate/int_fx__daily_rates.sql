-- Sparse ECB feed -> dense daily rate per currency (forward-filled). USD = 1.0.
with raw_spine as (
    select dateadd(day, seq4(), to_date('2024-12-31')) as rate_date
    from table(generator(rowcount => 400))
),
date_spine as (
    select rate_date from raw_spine where rate_date <= to_date('2026-01-02')
),
currencies as (
    select distinct quote_currency as currency from {{ ref('stg_api__fx_rates') }}
    union
    select 'USD' as currency
),
spine as (
    select s.rate_date, c.currency
    from date_spine s
    cross join currencies c
),
joined as (
    select
        sp.rate_date,
        sp.currency,
        fx.rate_to_usd as raw_rate
    from spine sp
    left join {{ ref('stg_api__fx_rates') }} fx
        on fx.rate_date = sp.rate_date
       and fx.quote_currency = sp.currency
),
filled as (
    select
        rate_date,
        currency,
        case
            when currency = 'USD' then 1.0
            else last_value(raw_rate ignore nulls) over (
                     partition by currency
                     order by rate_date
                     rows between unbounded preceding and current row)
        end as rate_to_usd
    from joined
)
select * from filled
