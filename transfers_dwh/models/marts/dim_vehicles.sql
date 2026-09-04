select
    vehicle_id,
    plate_number,
    car_model,
    is_active as is_vehicle_active,
    created_at as vehicle_registered_at,
    updated_at as vehicle_updated_at
from {{ ref('stg_vehicles') }}
