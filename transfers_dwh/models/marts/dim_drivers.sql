select
    d.driver_id,
    u.user_id,
    u.first_name as driver_name,
    u.phone_number as driver_phone,
    u.user_role,
    d.is_driver_active,
    u.is_active as is_user_active,
    d.created_at as driver_registered_at,
    d.updated_at as driver_updated_at
from {{ ref('stg_drivers') }} as d
left join {{ ref('stg_users') }} as u
on d.user_id = u.user_id