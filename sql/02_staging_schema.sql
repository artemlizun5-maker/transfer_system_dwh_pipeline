-- DROP SCHEMA staging;

CREATE SCHEMA staging AUTHORIZATION postgres;

-- DROP SEQUENCE etl_pipeline_errors_error_id_seq;

CREATE SEQUENCE etl_pipeline_errors_error_id_seq
	INCREMENT BY 1
	MINVALUE 1
	MAXVALUE 9223372036854775807
	START 1
	CACHE 1
	NO CYCLE;-- staging.drivers определение

-- Drop table

-- DROP TABLE drivers;

CREATE TABLE drivers (
	driver_id int4 NOT NULL,
	user_id int8 NULL,
	is_active bool NULL,
	created_at timestamptz NULL,
	updated_at timestamptz NULL,
	_staged_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	CONSTRAINT drivers_driver_id_not_null NOT NULL driver_id,
	CONSTRAINT drivers_pkey PRIMARY KEY (driver_id)
);


-- staging.etl_control определение

-- Drop table

-- DROP TABLE etl_control;

CREATE TABLE etl_control (
	table_name text NOT NULL,
	last_loaded_at timestamptz DEFAULT '1900-01-01 01:50:00+01:50'::timestamp with time zone NOT NULL,
	CONSTRAINT etl_control_last_loaded_at_not_null NOT NULL last_loaded_at,
	CONSTRAINT etl_control_pkey PRIMARY KEY (table_name),
	CONSTRAINT etl_control_table_name_not_null NOT NULL table_name
);


-- staging.etl_pipeline_errors определение

-- Drop table

-- DROP TABLE etl_pipeline_errors;

CREATE TABLE etl_pipeline_errors (
	error_id bigserial NOT NULL,
	table_name text NOT NULL,
	error_message text NOT NULL,
	occurred_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	CONSTRAINT etl_pipeline_errors_error_id_not_null NOT NULL error_id,
	CONSTRAINT etl_pipeline_errors_error_message_not_null NOT NULL error_message,
	CONSTRAINT etl_pipeline_errors_pkey PRIMARY KEY (error_id),
	CONSTRAINT etl_pipeline_errors_table_name_not_null NOT NULL table_name
);


-- staging.order_status_history определение

-- Drop table

-- DROP TABLE order_status_history;

CREATE TABLE order_status_history (
	history_id int8 NOT NULL,
	order_id int4 NULL,
	old_status varchar(20) NULL,
	new_status varchar(20) NULL,
	changed_at timestamptz NULL,
	updated_by_user_id int8 NULL,
	_staged_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	CONSTRAINT order_status_history_history_id_not_null NOT NULL history_id,
	CONSTRAINT order_status_history_pkey PRIMARY KEY (history_id)
);


-- staging.orders определение

-- Drop table

-- DROP TABLE orders;

CREATE TABLE orders (
	order_id int4 NOT NULL,
	client_name varchar(128) NULL,
	client_phone varchar(32) NULL,
	passengers_count int4 NULL,
	pickup_address text NULL,
	dropoff_address text NULL,
	scheduled_pickup_at timestamptz NULL,
	requested_car_model varchar(64) NULL,
	price numeric(10, 2) NULL,
	notes text NULL,
	status varchar(20) NULL,
	driver_id int4 NULL,
	vehicle_id int4 NULL,
	created_by_user_id int8 NULL,
	created_at timestamptz NULL,
	updated_at timestamptz NULL,
	completed_at timestamptz NULL,
	updated_by_user_id int8 NULL,
	_staged_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	CONSTRAINT orders_order_id_not_null NOT NULL order_id,
	CONSTRAINT orders_pkey PRIMARY KEY (order_id)
);


-- staging.users определение

-- Drop table

-- DROP TABLE users;

CREATE TABLE users (
	user_id int8 NOT NULL,
	first_name varchar(128) NULL,
	phone_number varchar(32) NULL,
	"role" varchar(20) NULL,
	is_active bool NULL,
	created_at timestamptz NULL,
	updated_at timestamptz NULL,
	_staged_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	CONSTRAINT users_pkey PRIMARY KEY (user_id),
	CONSTRAINT users_user_id_not_null NOT NULL user_id
);


-- staging.vehicles определение

-- Drop table

-- DROP TABLE vehicles;

CREATE TABLE vehicles (
	vehicle_id int4 NOT NULL,
	plate_number varchar(16) NULL,
	model varchar(64) NULL,
	is_active bool NULL,
	created_at timestamptz NULL,
	updated_at timestamptz NULL,
	_staged_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	CONSTRAINT vehicles_pkey PRIMARY KEY (vehicle_id),
	CONSTRAINT vehicles_vehicle_id_not_null NOT NULL vehicle_id
);



-- DROP PROCEDURE staging.prc_load_drivers();

CREATE OR REPLACE PROCEDURE staging.prc_load_drivers()
 LANGUAGE plpgsql
AS $procedure$
DECLARE 
    v_watermark TIMESTAMPTZ;
    v_new_watermark TIMESTAMPTZ;
    v_rows_synced INT;
BEGIN
    SELECT last_loaded_at INTO v_watermark 
    FROM staging.etl_control
    WHERE table_name = 'drivers';
    
    CREATE TEMP TABLE batch ON COMMIT DROP AS 
    SELECT * FROM oltp.drivers WHERE updated_at > v_watermark;
    
    GET DIAGNOSTICS v_rows_synced = ROW_COUNT;
    IF v_rows_synced = 0 THEN
        RAISE NOTICE 'Нет изменений (drivers)';
        RETURN;
    END IF;
    
    INSERT INTO staging.drivers (driver_id, user_id, is_active, created_at, updated_at, _staged_at)
    SELECT driver_id, user_id, is_active, created_at, updated_at, CURRENT_TIMESTAMP 
    FROM batch
    ON CONFLICT (driver_id) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        is_active = EXCLUDED.is_active,
        updated_at = EXCLUDED.updated_at,
        _staged_at = EXCLUDED._staged_at;
    
    SELECT MAX(updated_at) INTO v_new_watermark FROM batch;
    
    UPDATE staging.etl_control
    SET last_loaded_at = v_new_watermark
    WHERE table_name = 'drivers';
    
    RAISE NOTICE 'Синхронизировано % водителей, watermark: %', v_rows_synced, v_new_watermark;

EXCEPTION WHEN OTHERS THEN
    INSERT INTO staging.etl_pipeline_errors(table_name, error_message, occurred_at)
    VALUES ('drivers', SQLERRM, CURRENT_TIMESTAMP);
    RAISE NOTICE 'Ошибка синхронизации drivers: %', SQLERRM;
END $procedure$
;

-- DROP PROCEDURE staging.prc_load_order_status_history();

CREATE OR REPLACE PROCEDURE staging.prc_load_order_status_history()
 LANGUAGE plpgsql
AS $procedure$
DECLARE 
    v_watermark TIMESTAMPTZ;
    v_new_watermark TIMESTAMPTZ;
    v_rows_synced INT;
BEGIN
    SELECT last_loaded_at INTO v_watermark FROM staging.etl_control WHERE table_name = 'order_status_history';
    
    CREATE TEMP TABLE batch ON COMMIT DROP AS 
    SELECT * FROM oltp.order_status_history WHERE changed_at > v_watermark;
    
    GET DIAGNOSTICS v_rows_synced = ROW_COUNT;
    IF v_rows_synced = 0 THEN
        RAISE NOTICE 'Нет изменений (order_status_history)';
        RETURN;
    END IF;
    
    INSERT INTO staging.order_status_history (history_id, order_id, old_status, new_status, changed_at, updated_by_user_id, _staged_at)
    SELECT history_id, order_id, old_status, new_status, changed_at, updated_by_user_id, CURRENT_TIMESTAMP 
    FROM batch
    ON CONFLICT (history_id) DO NOTHING;
    
    SELECT MAX(changed_at) INTO v_new_watermark FROM batch;
    
    UPDATE staging.etl_control SET last_loaded_at = v_new_watermark WHERE table_name = 'order_status_history';
    RAISE NOTICE 'Синхронизировано % статусов, watermark: %', v_rows_synced, v_new_watermark;

EXCEPTION WHEN OTHERS THEN
    INSERT INTO staging.etl_pipeline_errors(table_name, error_message, occurred_at)
    VALUES ('order_status_history', SQLERRM, CURRENT_TIMESTAMP);
    RAISE NOTICE 'Ошибка синхронизации history: %', SQLERRM;
END $procedure$
;

-- DROP PROCEDURE staging.prc_load_orders();

CREATE OR REPLACE PROCEDURE staging.prc_load_orders()
 LANGUAGE plpgsql
AS $procedure$
declare 
v_watermark TIMESTAMPTZ;
v_new_watermark TIMESTAMPTZ;
v_rows_synced INT;
begin
	select last_loaded_at into v_watermark 
	from staging.etl_control
	where table_name = 'orders';
	
	create temp table batch on commit drop as 
	select * from oltp.orders where updated_at>v_watermark;
	
	get diagnostics v_rows_synced = row_count;
	if v_rows_synced = 0 then
		raise notice 'Нет изменений';
		return;
	end if;
	
	INSERT INTO staging.orders (
        order_id, client_name, client_phone, passengers_count,
        pickup_address, dropoff_address, scheduled_pickup_at,
        requested_car_model, price, notes, status,
        driver_id, vehicle_id, created_by_user_id,
        created_at, updated_at, completed_at, updated_by_user_id, _staged_at
    )
    SELECT order_id, client_name, client_phone, passengers_count,
           pickup_address, dropoff_address, scheduled_pickup_at,
           requested_car_model, price, notes, status,
           driver_id, vehicle_id, created_by_user_id,
           created_at, updated_at, completed_at, updated_by_user_id, CURRENT_TIMESTAMP
    FROM batch
    ON CONFLICT (order_id) DO UPDATE SET
        client_name = EXCLUDED.client_name,
        client_phone = EXCLUDED.client_phone,
        passengers_count = EXCLUDED.passengers_count,
        pickup_address = EXCLUDED.pickup_address,
        dropoff_address = EXCLUDED.dropoff_address,
        scheduled_pickup_at = EXCLUDED.scheduled_pickup_at,
        requested_car_model = EXCLUDED.requested_car_model,
        price = EXCLUDED.price,
        notes = EXCLUDED.notes,
        status = EXCLUDED.status,
        driver_id = EXCLUDED.driver_id,
        vehicle_id = EXCLUDED.vehicle_id,
        updated_at = EXCLUDED.updated_at,
        completed_at = EXCLUDED.completed_at,
        updated_by_user_id = EXCLUDED.updated_by_user_id,
        _staged_at = EXCLUDED._staged_at;
	
	select max(updated_at) into v_new_watermark from batch;
	
	update staging.etl_control
	set last_loaded_at = v_new_watermark
	where table_name = 'orders';
	
	raise notice 'Синхронизировано % заказов, watermark: %', v_rows_synced, v_new_watermark;

exception when others then
	insert into staging.etl_pipeline_errors(table_name, error_message, occurred_at)
	values ('orders', SQLERRM, CURRENT_TIMESTAMP);
RAISE NOTICE 'Ошибка синхронизации orders: %', SQLERRM;
END $procedure$
;

-- DROP PROCEDURE staging.prc_load_users();

CREATE OR REPLACE PROCEDURE staging.prc_load_users()
 LANGUAGE plpgsql
AS $procedure$
declare 
v_watermark timestamptz;
v_new_watermark timestamptz;
v_rows_synced int;
begin
	SELECT last_loaded_at into v_watermark from staging.etl_control 
	where table_name = 'users';

create temp table batch on commit drop as
select * from oltp.users where updated_at > v_watermark;
get diagnostics v_rows_synced = row_count;
if v_rows_synced = 0 then
raise notice 'Нет изменений (users)';
return;
end if;

INSERT INTO staging.users (user_id, first_name, phone_number, role, is_active, created_at, updated_at, _staged_at)
SELECT user_id, first_name, phone_number, role, is_active, created_at, updated_at, CURRENT_TIMESTAMP 
FROM batch
ON CONFLICT (user_id) DO UPDATE SET
       	first_name = EXCLUDED.first_name,
        phone_number = EXCLUDED.phone_number,
        role = EXCLUDED.role,
        is_active = EXCLUDED.is_active,
        updated_at = EXCLUDED.updated_at,
        _staged_at = EXCLUDED._staged_at;

Select max(updated_at) into v_new_watermark from batch;

update staging.etl_control set last_loaded_at = v_new_watermark
where table_name = 'users';
RAISE NOTICE 'Синхронизировано % пользователей, watermark: %', v_rows_synced, v_new_watermark;

EXCEPTION WHEN OTHERS THEN
    INSERT INTO staging.etl_pipeline_errors(table_name, error_message, occurred_at)
    VALUES ('users', SQLERRM, CURRENT_TIMESTAMP);
    RAISE NOTICE 'Ошибка синхронизации users: %', SQLERRM;
end $procedure$
;

-- DROP PROCEDURE staging.prc_load_vehicles();

CREATE OR REPLACE PROCEDURE staging.prc_load_vehicles()
 LANGUAGE plpgsql
AS $procedure$
DECLARE 
    v_watermark TIMESTAMPTZ;
    v_new_watermark TIMESTAMPTZ;
    v_rows_synced INT;
BEGIN
    SELECT last_loaded_at INTO v_watermark FROM staging.etl_control WHERE table_name = 'vehicles';    
    CREATE TEMP TABLE batch ON COMMIT DROP AS 
    SELECT * FROM oltp.vehicles WHERE updated_at > v_watermark;
    
    GET DIAGNOSTICS v_rows_synced = ROW_COUNT;
    IF v_rows_synced = 0 THEN
        RAISE NOTICE 'Нет изменений (vehicles)';
        RETURN;
    END IF;
    
    INSERT INTO staging.vehicles (vehicle_id, plate_number, model, is_active, created_at, updated_at, _staged_at)
    SELECT vehicle_id, plate_number, model, is_active, created_at, updated_at, CURRENT_TIMESTAMP 
    FROM batch
    ON CONFLICT (vehicle_id) DO UPDATE SET
        plate_number = EXCLUDED.plate_number,
        model = EXCLUDED.model,
        is_active = EXCLUDED.is_active,
        updated_at = EXCLUDED.updated_at,
        _staged_at = EXCLUDED._staged_at;
    
    SELECT MAX(updated_at) INTO v_new_watermark FROM batch;
    
    UPDATE staging.etl_control SET last_loaded_at = v_new_watermark WHERE table_name = 'vehicles';
    RAISE NOTICE 'Синхронизировано % машин, watermark: %', v_rows_synced, v_new_watermark;

EXCEPTION WHEN OTHERS THEN
    INSERT INTO staging.etl_pipeline_errors(table_name, error_message, occurred_at)
    VALUES ('vehicles', SQLERRM, CURRENT_TIMESTAMP);
    RAISE NOTICE 'Ошибка синхронизации vehicles: %', SQLERRM;
END $procedure$
;