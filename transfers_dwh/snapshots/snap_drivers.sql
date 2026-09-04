{% snapshot snap_drivers %}

{{
    config(
        target_schema='dwh_marts',
        unique_key='driver_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=True
    )
}}

select
    driver_id,
    user_id,
    is_driver_active,
    created_at,
    updated_at::timestamp as updated_at
from {{ ref('stg_drivers') }}

{% endsnapshot %}