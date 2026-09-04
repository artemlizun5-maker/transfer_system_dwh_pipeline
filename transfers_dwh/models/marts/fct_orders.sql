{{
    config(
        materialized='incremental',
        unique_key='order_id',
        on_schema_change='sync_all_columns'
    )
}}

select
    order_id,
    driver_id,
    vehicle_id,
    created_by_user_id,
    updated_by_user_id,

    client_name,
    client_phone,
    passengers_count,
    pickup_address,
    dropoff_address,
    requested_car_model,
    order_status,
    notes,

    price,
    (order_status = 'completed')::int as is_completed,
    (order_status = 'cancelled')::int as is_cancelled,
    case 
        when completed_at is not null and scheduled_pickup_at is not null 
        then round((extract(epoch from (completed_at - scheduled_pickup_at)) / 60.0)::numeric, 2)
        else null
    end as trip_duration_minutes,
    scheduled_pickup_at,
    created_at,
    updated_at,
    completed_at
from {{ ref('stg_orders') }}

{% if is_incremental() %}
    where updated_at > (select max(updated_at) from {{this}})
{% endif %}