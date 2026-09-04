select
    driver_id,
    user_id,
    is_active as is_driver_active,
    created_at,
    updated_at,
    _staged_at
from {{ source('staging', 'drivers') }}