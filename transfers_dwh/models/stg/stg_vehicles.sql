select
    vehicle_id,
    plate_number,
    model as car_model,
    is_active,
    created_at,
    updated_at,
    _staged_at
from {{ source('staging', 'vehicles') }}