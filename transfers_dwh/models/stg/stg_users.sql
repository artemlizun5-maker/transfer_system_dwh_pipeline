select
    user_id,
    first_name,
    phone_number,
    role as user_role,
    is_active,
    created_at,
    updated_at,
    _staged_at
from {{ source('staging', 'users') }}