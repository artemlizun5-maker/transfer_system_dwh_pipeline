{% snapshot snap_users %}

{{
    config(
        target_schema='dwh_marts',
        unique_key='user_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=True
    )
}}

select
    user_id,
    first_name,
    phone_number,
    user_role,
    is_active,
    created_at,
    updated_at::timestamp as updated_at
from {{ ref('stg_users') }}

{% endsnapshot %}