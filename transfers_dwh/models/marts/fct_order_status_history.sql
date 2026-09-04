{{
    config(
        materialized='incremental',
        unique_key='history_id',
        on_schema_change='sync_all_columns'
    )
}}

with source_data as (
    select *
    from {{ ref('stg_order_status_history') }}

    {% if is_incremental() %}
        where order_id in (
            select distinct order_id
            from {{ ref('stg_order_status_history') }}
            where changed_at > (select max(status_started_at) from {{ this }})
        )
    {% endif %}
),
status_transitions as (
    select
        history_id,
        order_id,
        old_status,
        new_status as current_status,
        changed_at as status_started_at,
        updated_by_user_id,
        
        lead(changed_at) over (
            partition by order_id 
            order by changed_at asc
        ) as status_ended_at,
        
        lead(new_status) over (
            partition by order_id 
            order by changed_at asc
        ) as next_status

    from source_data
)

select
    history_id,
    order_id,
    old_status,
    current_status,
    next_status,
    updated_by_user_id,
    status_started_at,
    status_ended_at,

    case 
        when status_ended_at is not null 
        then extract(epoch from (status_ended_at - status_started_at))::int
        else null
    end as duration_seconds,

    case 
        when status_ended_at is not null 
        then round((extract(epoch from (status_ended_at - status_started_at)) / 60.0)::numeric, 2)
        else null
    end as duration_minutes,

    status_ended_at is null as is_current_status

from status_transitions