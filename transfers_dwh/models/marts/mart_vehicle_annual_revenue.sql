{{ config(materialized='table') }}

with completed_orders as (
    select
        order_id,
        vehicle_id,
        price,
        scheduled_pickup_at 
    from {{ ref('fct_orders') }}
    where order_status = 'completed'
      and scheduled_pickup_at >= '2025-01-01'::timestamp 
      and scheduled_pickup_at < '2026-01-01'::timestamp
)

select 
    v.plate_number,
    v.car_model,
    sum(o.price) as total_annual_revenue,
    count(o.order_id) as total_trips
from completed_orders o
left join {{ ref('snap_vehicles') }} v
    on o.vehicle_id = v.vehicle_id
    and o.scheduled_pickup_at >= v.dbt_valid_from
    and o.scheduled_pickup_at < coalesce(v.dbt_valid_to, '9999-12-31'::timestamp)
group by 
    v.plate_number,
    v.car_model
order by 
    total_annual_revenue desc