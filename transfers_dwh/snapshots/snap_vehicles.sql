{% snapshot snap_vehicles %}

{{
    config(
        target_schema='dwh_marts',
        unique_key='vehicle_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=True
    )
}}

select
    vehicle_id,
    plate_number,
    car_model,
    is_active,
    created_at,
    updated_at::timestamp as updated_at
from {{ ref('stg_vehicles') }}

{% endsnapshot %}