{{ config(materialized='table') }}

with calendar as (
    select distinct scheduled_pickup_at::date as report_date
    from {{ ref('fct_orders') }}
    where scheduled_pickup_at is not null
),
driver_daily_facts as (
    select
        driver_id,
        scheduled_pickup_at::date as report_date,
        sum(is_completed) as total_completed_trips,
        sum(is_cancelled) as total_cancelled_trips,
        sum(case when is_completed = 1 then price else 0 end) as total_revenue,
        round(avg(case when is_completed = 1 then price end), 2) as average_trip_price,
        sum(trip_duration_minutes) as total_duration_minutes
    from {{ ref('fct_orders') }}
    group by 1, 2
)
select 
    c.report_date,
    d.driver_id,
    d.driver_name,
    d.driver_phone,
    coalesce(f.total_completed_trips, 0) as total_completed_trips,
    coalesce(f.total_cancelled_trips, 0) as total_cancelled_trips,
    coalesce(f.total_revenue, 0) as total_revenue,
    coalesce(f.average_trip_price, 0) as average_trip_price,
    coalesce(f.total_duration_minutes, 0) as total_duration_minutes
from calendar c
cross join {{ ref('dim_drivers') }} d
left join driver_daily_facts f 
    on d.driver_id = f.driver_id 
    and c.report_date = f.report_date
where d.is_driver_active = true
order by c.report_date desc, d.driver_name