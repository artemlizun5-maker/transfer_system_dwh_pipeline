-- DROP SCHEMA oltp;

CREATE SCHEMA oltp AUTHORIZATION postgres;

-- DROP SEQUENCE drivers_driver_id_seq;

CREATE SEQUENCE drivers_driver_id_seq
	INCREMENT BY 1
	MINVALUE 1
	MAXVALUE 2147483647
	START 1
	CACHE 1
	NO CYCLE;
-- DROP SEQUENCE order_status_history_history_id_seq;

CREATE SEQUENCE order_status_history_history_id_seq
	INCREMENT BY 1
	MINVALUE 1
	MAXVALUE 9223372036854775807
	START 1
	CACHE 1
	NO CYCLE;
-- DROP SEQUENCE orders_order_id_seq;

CREATE SEQUENCE orders_order_id_seq
	INCREMENT BY 1
	MINVALUE 1
	MAXVALUE 2147483647
	START 1
	CACHE 1
	NO CYCLE;
-- DROP SEQUENCE vehicles_vehicle_id_seq;

CREATE SEQUENCE vehicles_vehicle_id_seq
	INCREMENT BY 1
	MINVALUE 1
	MAXVALUE 2147483647
	START 1
	CACHE 1
	NO CYCLE;-- oltp.users определение

-- Drop table

-- DROP TABLE users;

CREATE TABLE users (
	user_id int8 NOT NULL,
	first_name varchar(128) NOT NULL,
	phone_number varchar(32) NOT NULL,
	"role" varchar(20) NOT NULL,
	is_active bool DEFAULT true NOT NULL,
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
	CONSTRAINT users_first_name_not_null NOT NULL first_name,
	CONSTRAINT users_is_active_not_null NOT NULL is_active,
	CONSTRAINT users_phone_number_not_null NOT NULL phone_number,
	CONSTRAINT users_pkey PRIMARY KEY (user_id),
	CONSTRAINT users_role_check CHECK (((role)::text = ANY ((ARRAY['manager'::character varying, 'admin'::character varying, 'driver'::character varying])::text[]))),
	CONSTRAINT users_role_not_null NOT NULL role,
	CONSTRAINT users_updated_at_not_null NOT NULL updated_at,
	CONSTRAINT users_user_id_not_null NOT NULL user_id
);

-- Table Triggers

create trigger trg_user_create_driver after
insert
    or
update
    of role on
    oltp.users for each row execute function oltp.func_create_driver();
create trigger trg_users_set_updated_at before
update
    on
    oltp.users for each row execute function oltp.func_set_updated_at();


-- oltp.vehicles определение

-- Drop table

-- DROP TABLE vehicles;

CREATE TABLE vehicles (
	vehicle_id serial4 NOT NULL,
	plate_number varchar(16) NOT NULL,
	model varchar(64) NOT NULL,
	is_active bool DEFAULT true NOT NULL,
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
	CONSTRAINT vehicles_is_active_not_null NOT NULL is_active,
	CONSTRAINT vehicles_model_not_null NOT NULL model,
	CONSTRAINT vehicles_pkey PRIMARY KEY (vehicle_id),
	CONSTRAINT vehicles_plate_number_key UNIQUE (plate_number),
	CONSTRAINT vehicles_plate_number_not_null NOT NULL plate_number,
	CONSTRAINT vehicles_updated_at_not_null NOT NULL updated_at,
	CONSTRAINT vehicles_vehicle_id_not_null NOT NULL vehicle_id
);
CREATE INDEX idx_vehicles_updated_at ON oltp.vehicles USING btree (updated_at);

-- Table Triggers

create trigger trg_vehicles_set_updated_at before
update
    on
    oltp.vehicles for each row execute function oltp.func_set_updated_at();


-- oltp.drivers определение

-- Drop table

-- DROP TABLE drivers;

CREATE TABLE drivers (
	driver_id serial4 NOT NULL,
	user_id int8 NOT NULL,
	is_active bool DEFAULT true NOT NULL,
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
	CONSTRAINT drivers_driver_id_not_null NOT NULL driver_id,
	CONSTRAINT drivers_is_active_not_null NOT NULL is_active,
	CONSTRAINT drivers_pkey PRIMARY KEY (driver_id),
	CONSTRAINT drivers_updated_at_not_null NOT NULL updated_at,
	CONSTRAINT drivers_user_id_key UNIQUE (user_id),
	CONSTRAINT drivers_user_id_not_null NOT NULL user_id,
	CONSTRAINT drivers_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE RESTRICT
);
CREATE INDEX ind_drivers_updated_at ON oltp.drivers USING btree (updated_at);

-- Table Triggers

create trigger trg_drivers_check_role before
insert
    or
update
    of user_id on
    oltp.drivers for each row execute function oltp.func_check_driver_role();
create trigger trg_drivers_set_updated_at before
update
    on
    oltp.drivers for each row execute function oltp.func_set_updated_at();


-- oltp.orders определение

-- Drop table

-- DROP TABLE orders;

CREATE TABLE orders (
	order_id serial4 NOT NULL,
	client_name varchar(128) NOT NULL,
	client_phone varchar(32) NOT NULL,
	passengers_count int4 DEFAULT 1 NOT NULL,
	pickup_address text NOT NULL,
	dropoff_address text NOT NULL,
	scheduled_pickup_at timestamptz NOT NULL,
	requested_car_model varchar(64) NOT NULL,
	price numeric(10, 2) NOT NULL,
	notes text NULL,
	status varchar(20) DEFAULT 'created'::character varying NOT NULL,
	driver_id int4 NULL,
	vehicle_id int4 NULL,
	created_by_user_id int8 NULL,
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	completed_at timestamptz NULL,
	updated_by_user_id int8 NULL,
	CONSTRAINT chk_order_completion_time CHECK (((completed_at IS NULL) OR (completed_at >= created_at))),
	CONSTRAINT orders_client_name_not_null NOT NULL client_name,
	CONSTRAINT orders_client_phone_not_null NOT NULL client_phone,
	CONSTRAINT orders_dropoff_address_not_null NOT NULL dropoff_address,
	CONSTRAINT orders_order_id_not_null NOT NULL order_id,
	CONSTRAINT orders_passengers_count_check CHECK (((passengers_count > 0) AND (passengers_count <= 10))),
	CONSTRAINT orders_passengers_count_not_null NOT NULL passengers_count,
	CONSTRAINT orders_pickup_address_not_null NOT NULL pickup_address,
	CONSTRAINT orders_pkey PRIMARY KEY (order_id),
	CONSTRAINT orders_price_check CHECK ((price > (0)::numeric)),
	CONSTRAINT orders_price_not_null NOT NULL price,
	CONSTRAINT orders_requested_car_model_not_null NOT NULL requested_car_model,
	CONSTRAINT orders_scheduled_pickup_at_not_null NOT NULL scheduled_pickup_at,
	CONSTRAINT orders_status_check CHECK (((status)::text = ANY ((ARRAY['created'::character varying, 'assigned'::character varying, 'in_progress'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[]))),
	CONSTRAINT orders_status_not_null NOT NULL status,
	CONSTRAINT orders_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES users(user_id),
	CONSTRAINT orders_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES drivers(driver_id) ON DELETE RESTRICT,
	CONSTRAINT orders_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES users(user_id),
	CONSTRAINT orders_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id) ON DELETE RESTRICT
);
CREATE INDEX ind_orders_updated_at ON oltp.orders USING btree (updated_at);

-- Table Triggers

create trigger trg_orders_set_updated_at before
update
    on
    oltp.orders for each row execute function oltp.func_set_updated_at();
create trigger trg_status_change after
insert
    or
update
    of status on
    oltp.orders for each row execute function oltp.func_status_change();


-- oltp.order_status_history определение

-- Drop table

-- DROP TABLE order_status_history;

CREATE TABLE order_status_history (
	history_id bigserial NOT NULL,
	order_id int4 NOT NULL,
	old_status varchar(20) NULL,
	new_status varchar(20) NOT NULL,
	changed_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	updated_by_user_id int8 NULL,
	CONSTRAINT order_status_history_history_id_not_null NOT NULL history_id,
	CONSTRAINT order_status_history_new_status_not_null NOT NULL new_status,
	CONSTRAINT order_status_history_order_id_not_null NOT NULL order_id,
	CONSTRAINT order_status_history_pkey PRIMARY KEY (history_id),
	CONSTRAINT order_status_history_order_id_fkey FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE RESTRICT
);



-- DROP FUNCTION oltp.func_check_driver_role();

CREATE OR REPLACE FUNCTION oltp.func_check_driver_role()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM oltp.users WHERE user_id = NEW.user_id AND role = 'driver'
    ) THEN
        RAISE EXCEPTION 'Пользователь % не имеет роли driver, нельзя добавить в drivers', NEW.user_id;
    END IF;
    RETURN NEW;
END;
$function$
;

-- DROP FUNCTION oltp.func_create_driver();

CREATE OR REPLACE FUNCTION oltp.func_create_driver()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF (TG_OP = 'INSERT' AND NEW.role = 'driver') 
       OR (TG_OP = 'UPDATE' AND OLD.role IS DISTINCT FROM NEW.role AND NEW.role = 'driver') THEN
        INSERT INTO oltp.drivers (user_id)
        VALUES (NEW.user_id)
        ON CONFLICT (user_id) DO UPDATE 
            SET is_active = TRUE;
    ELSIF TG_OP = 'UPDATE' AND OLD.role = 'driver' AND NEW.role != 'driver' THEN        
        UPDATE oltp.drivers 
        SET is_active = FALSE 
        WHERE user_id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$function$
;

-- DROP FUNCTION oltp.func_set_updated_at();

CREATE OR REPLACE FUNCTION oltp.func_set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$function$
;

-- DROP FUNCTION oltp.func_status_change();

CREATE OR REPLACE FUNCTION oltp.func_status_change()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO oltp.order_status_history (
            order_id, old_status, new_status, changed_at, updated_by_user_id
        ) VALUES (
            NEW.order_id, NULL, NEW.status, CURRENT_TIMESTAMP, NEW.created_by_user_id
        );
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO oltp.order_status_history (
            order_id, old_status, new_status, changed_at, updated_by_user_id
        ) VALUES (
            NEW.order_id, OLD.status, NEW.status, CURRENT_TIMESTAMP, NEW.updated_by_user_id
        );
        IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
            NEW.completed_at = CURRENT_TIMESTAMP;
        END IF;
    END IF;

    RETURN NEW;
END;
$function$
;