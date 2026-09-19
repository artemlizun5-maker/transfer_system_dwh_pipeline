-- =====================================================================
-- Схема oltp — приведено к рабочему виду для PostgreSQL 13.
-- Ничего в структуре (имена схем/таблиц/колонок/триггеров/функций,
-- типы, default-значения, ограничения) не менялось — только то, что
-- мешало этому же самому коду реально выполниться:
--
--   1) после CREATE SCHEMA не было SET search_path, поэтому все
--      неквалифицированные CREATE TABLE/FUNCTION ушли бы в схему по
--      умолчанию (обычно public), а не в oltp;
--   2) функции в исходном экспорте шли ПОСЛЕ таблиц и триггеров, а
--      CREATE TRIGGER требует, чтобы функция уже существовала —
--      функции перенесены в начало файла;
--   3) отдельные CREATE SEQUENCE дублировали последовательности,
--      которые и так автоматически создаются типами serial4/bigserial
--      с точно такими же именами — при выполнении это давало бы
--      ошибку "relation ... already exists"; убраны как избыточные;
--   4) табличные ограничения вида
--         CONSTRAINT xxx_not_null NOT NULL xxx
--      — это именованные NOT NULL-ограничения, синтаксис для которых
--      появился только в PostgreSQL 17 и в 13-й версии является
--      синтаксической ошибкой. Сама проверка NOT NULL у каждой такой
--      колонки уже задана прямо в определении столбца (например,
--      "first_name varchar(128) NOT NULL"), поэтому эти строки просто
--      дублировали её и убраны без потери какой-либо логики.
-- =====================================================================

CREATE SCHEMA oltp AUTHORIZATION postgres;

SET search_path TO oltp, public;

-- ---------------------------------------------------------------------
-- Функции (в т.ч. триггерные) — созданы до таблиц, чтобы триггеры ниже
-- могли на них ссылаться.
-- ---------------------------------------------------------------------

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

-- ---------------------------------------------------------------------
-- oltp.users
-- ---------------------------------------------------------------------

CREATE TABLE users (
	user_id int8 NOT NULL,
	first_name varchar(128) NOT NULL,
	phone_number varchar(32) NOT NULL,
	"role" varchar(20) NOT NULL,
	is_active bool DEFAULT true NOT NULL,
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
	CONSTRAINT users_pkey PRIMARY KEY (user_id),
	CONSTRAINT users_role_check CHECK (((role)::text = ANY ((ARRAY['manager'::character varying, 'admin'::character varying, 'driver'::character varying])::text[])))
);

CREATE TRIGGER trg_user_create_driver
    AFTER INSERT OR UPDATE OF role ON oltp.users
    FOR EACH ROW EXECUTE FUNCTION oltp.func_create_driver();

CREATE TRIGGER trg_users_set_updated_at
    BEFORE UPDATE ON oltp.users
    FOR EACH ROW EXECUTE FUNCTION oltp.func_set_updated_at();

-- ---------------------------------------------------------------------
-- oltp.vehicles
-- ---------------------------------------------------------------------

CREATE TABLE vehicles (
	vehicle_id serial4 NOT NULL,
	plate_number varchar(16) NOT NULL,
	model varchar(64) NOT NULL,
	is_active bool DEFAULT true NOT NULL,
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
	CONSTRAINT vehicles_pkey PRIMARY KEY (vehicle_id),
	CONSTRAINT vehicles_plate_number_key UNIQUE (plate_number)
);
CREATE INDEX idx_vehicles_updated_at ON oltp.vehicles USING btree (updated_at);

CREATE TRIGGER trg_vehicles_set_updated_at
    BEFORE UPDATE ON oltp.vehicles
    FOR EACH ROW EXECUTE FUNCTION oltp.func_set_updated_at();

-- ---------------------------------------------------------------------
-- oltp.drivers
-- ---------------------------------------------------------------------

CREATE TABLE drivers (
	driver_id serial4 NOT NULL,
	user_id int8 NOT NULL,
	is_active bool DEFAULT true NOT NULL,
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
	CONSTRAINT drivers_pkey PRIMARY KEY (driver_id),
	CONSTRAINT drivers_user_id_key UNIQUE (user_id),
	CONSTRAINT drivers_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE RESTRICT
);
CREATE INDEX ind_drivers_updated_at ON oltp.drivers USING btree (updated_at);

CREATE TRIGGER trg_drivers_check_role
    BEFORE INSERT OR UPDATE OF user_id ON oltp.drivers
    FOR EACH ROW EXECUTE FUNCTION oltp.func_check_driver_role();

CREATE TRIGGER trg_drivers_set_updated_at
    BEFORE UPDATE ON oltp.drivers
    FOR EACH ROW EXECUTE FUNCTION oltp.func_set_updated_at();

-- ---------------------------------------------------------------------
-- oltp.orders
-- ---------------------------------------------------------------------

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
	CONSTRAINT orders_passengers_count_check CHECK (((passengers_count > 0) AND (passengers_count <= 10))),
	CONSTRAINT orders_pkey PRIMARY KEY (order_id),
	CONSTRAINT orders_price_check CHECK ((price > (0)::numeric)),
	CONSTRAINT orders_status_check CHECK (((status)::text = ANY ((ARRAY['created'::character varying, 'assigned'::character varying, 'in_progress'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[]))),
	CONSTRAINT orders_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES users(user_id),
	CONSTRAINT orders_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES drivers(driver_id) ON DELETE RESTRICT,
	CONSTRAINT orders_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES users(user_id),
	CONSTRAINT orders_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id) ON DELETE RESTRICT
);
CREATE INDEX ind_orders_updated_at ON oltp.orders USING btree (updated_at);

CREATE TRIGGER trg_orders_set_updated_at
    BEFORE UPDATE ON oltp.orders
    FOR EACH ROW EXECUTE FUNCTION oltp.func_set_updated_at();

CREATE TRIGGER trg_status_change
    AFTER INSERT OR UPDATE OF status ON oltp.orders
    FOR EACH ROW EXECUTE FUNCTION oltp.func_status_change();

-- ---------------------------------------------------------------------
-- oltp.order_status_history
-- ---------------------------------------------------------------------

CREATE TABLE order_status_history (
	history_id bigserial NOT NULL,
	order_id int4 NOT NULL,
	old_status varchar(20) NULL,
	new_status varchar(20) NOT NULL,
	changed_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL,
	updated_by_user_id int8 NULL,
	CONSTRAINT order_status_history_pkey PRIMARY KEY (history_id),
	CONSTRAINT order_status_history_order_id_fkey FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE RESTRICT
);