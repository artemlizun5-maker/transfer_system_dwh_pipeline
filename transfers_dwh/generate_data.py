import psycopg2
from psycopg2 import extras
from faker import Faker
import random
from datetime import timedelta

fake = Faker('ru_RU')

def generate_data():
    conn = psycopg2.connect(
        dbname="transfer_system", # проверь свое название БД
        user="postgres", 
        password="1234", 
        host="localhost", 
        port="5432"
    )
    cur = conn.cursor()

    print("Очистка базы...")
    # RESTART IDENTITY сбрасывает счетчики (ID снова начнутся с 1)
    cur.execute("TRUNCATE TABLE oltp.order_status_history, oltp.orders, oltp.drivers, oltp.vehicles, oltp.users RESTART IDENTITY CASCADE;")

    print("Отключение триггеров...")
    for table in ['users', 'drivers', 'vehicles', 'orders', 'order_status_history']:
        cur.execute(f"ALTER TABLE oltp.{table} DISABLE TRIGGER ALL;")

    base_date = fake.date_time_between("-1y", "-8m")
    
    # 1. Генерация пользователей (1 Менеджер, 2 Админа, 50 Водителей)
    users_data = [
        (1, fake.name(), fake.phone_number(), 'manager', base_date, base_date),
        (2, fake.name(), fake.phone_number(), 'admin', base_date, base_date),
        (3, fake.name(), fake.phone_number(), 'admin', base_date, base_date)
    ]
    for uid in range(1000, 1050):
        users_data.append((uid, fake.name(), fake.phone_number(), 'driver', base_date, base_date))
    
    extras.execute_values(cur, "INSERT INTO oltp.users (user_id, first_name, phone_number, role, created_at, updated_at) VALUES %s", users_data)
    
    # 2. Генерация водителей
    drivers_data = [(uid, base_date, base_date) for uid in range(1000, 1050)]
    extras.execute_values(cur, "INSERT INTO oltp.drivers (user_id, created_at, updated_at) VALUES %s", drivers_data)
    cur.execute("SELECT driver_id FROM oltp.drivers")
    driver_ids = [r[0] for r in cur.fetchall()]

    # 3. Генерация машин
    models = ['Toyota Camry', 'Mercedes-Benz E-Class', 'Volkswagen Multivan']
    veh_data = [(fake.unique.license_plate(), random.choice(models), True, base_date, base_date) for _ in range(50)]
    extras.execute_values(cur, "INSERT INTO oltp.vehicles (plate_number, model, is_active, created_at, updated_at) VALUES %s", veh_data)
    cur.execute("SELECT vehicle_id FROM oltp.vehicles")
    vehicle_ids = [r[0] for r in cur.fetchall()]

    # 4. Генерация заказов и истории
    print("Генерация 10 000 заказов...")
    orders_data = []
    history_records = []

    for order_id in range(1, 10001):
        # Жестко фиксируем распределение статусов: 80% выполнено, 15% отмена, 5% назначено на будущее
        status = random.choices(['completed', 'cancelled', 'assigned'], weights=[80, 15, 5])[0]
        
        if status in ['completed', 'cancelled']:
            # Дата поездки точно в прошлом
            scheduled_pickup_at = fake.date_time_between(start_date="-5m", end_date="-1d")
            created_at = scheduled_pickup_at - timedelta(days=random.randint(2, 14))
        else:
            # Дата поездки точно в будущем
            scheduled_pickup_at = fake.date_time_between(start_date="+1d", end_date="+14d")
            created_at = fake.date_time_between(start_date="-5d", end_date="now")
        
        assigned_at = created_at + timedelta(hours=random.randint(1, 48))
        in_progress_at = scheduled_pickup_at - timedelta(minutes=random.randint(10, 45))
        completed_at = scheduled_pickup_at + timedelta(minutes=random.randint(40, 180))
        cancelled_at = scheduled_pickup_at - timedelta(hours=random.randint(1, 24))

        actual_completed = completed_at if status == 'completed' else None
        updated_at = actual_completed if status == 'completed' else (cancelled_at if status == 'cancelled' else assigned_at)

        driver_id = random.choice(driver_ids)
        vehicle_id = random.choice(vehicle_ids)
        admin_id = random.choice([2, 3])
        manager_id = 1
        price = random.randint(1500, 15000)

        # Собираем данные заказа
        orders_data.append((
            order_id, fake.name(), fake.phone_number(), random.randint(1, 4), fake.address(), fake.address(),
            scheduled_pickup_at, random.choice(models), price, status, driver_id, vehicle_id,
            manager_id, admin_id, created_at, updated_at, actual_completed
        ))

        # Собираем историю статусов
        history_records.append((order_id, None, 'created', created_at, manager_id))
        
        if status in ['assigned', 'in_progress', 'completed', 'cancelled']:
            history_records.append((order_id, 'created', 'assigned', assigned_at, admin_id))
        
        if status == 'completed':
            history_records.append((order_id, 'assigned', 'in_progress', in_progress_at, admin_id))
            history_records.append((order_id, 'in_progress', 'completed', completed_at, admin_id))
        elif status == 'cancelled':
            history_records.append((order_id, 'assigned', 'cancelled', cancelled_at, admin_id))

    print("Запись в БД...")
    extras.execute_values(cur, """
        INSERT INTO oltp.orders (
            order_id, client_name, client_phone, passengers_count, pickup_address, dropoff_address, 
            scheduled_pickup_at, requested_car_model, price, status, driver_id, vehicle_id, 
            created_by_user_id, updated_by_user_id, created_at, updated_at, completed_at
        ) VALUES %s
    """, orders_data)

    extras.execute_values(cur, """
        INSERT INTO oltp.order_status_history (order_id, old_status, new_status, changed_at, updated_by_user_id)
        VALUES %s
    """, history_records)

    print("Включение триггеров...")
    for table in ['users', 'drivers', 'vehicles', 'orders', 'order_status_history']:
        cur.execute(f"ALTER TABLE oltp.{table} ENABLE TRIGGER ALL;")

    conn.commit()
    cur.close()
    conn.close()
    print("Готово!")

if __name__ == "__main__":
    generate_data()