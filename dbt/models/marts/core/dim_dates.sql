with raw_spine as (
    select dateadd(day, seq4(), to_date('2024-12-31')) as date_day
    from table(generator(rowcount => 400))
),
spine as (
    select date_day from raw_spine where date_day <= to_date('2026-01-02')
)
select
    to_number(to_char(date_day, 'YYYYMMDD')) as date_key,
    date_day,
    year(date_day)                           as year,
    quarter(date_day)                        as quarter,
    month(date_day)                          as month,
    monthname(date_day)                      as month_name,
    day(date_day)                            as day_of_month,
    dayofweek(date_day)                      as day_of_week,
    dayname(date_day)                        as day_name,
    iff(dayofweek(date_day) in (0, 6), true, false) as is_weekend
from spine
