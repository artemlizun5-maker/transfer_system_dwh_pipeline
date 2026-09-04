select
    history_id,
    order_id,
    old_status,
    new_status,
    changed_at,
    updated_by_user_id,
    _staged_at
from {{ source('staging', 'order_status_history') }}