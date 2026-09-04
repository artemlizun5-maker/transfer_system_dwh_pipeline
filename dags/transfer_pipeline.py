from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.operators.bash import BashOperator

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=1),
}

with DAG(
    dag_id='transfers_dwh_pipeline',
    default_args=default_args,
    description='Ежедневная инкрементальная загрузка и расчет витрин',
    schedule_interval='0 2 * * *', 
    start_date=datetime(2026, 9, 1),
    catchup=False,
    tags=['dwh', 'transfers_dwh', 'dbt'],
) as dag:

    load_to_staging = PostgresOperator(
        task_id='load_oltp_to_staging',
        postgres_conn_id='transfer_db_conn', 
        sql="""
            CALL staging.prc_load_users();
            CALL staging.prc_load_vehicles();
            CALL staging.prc_load_drivers();
            CALL staging.prc_load_orders();
            CALL staging.prc_load_order_status_history();
        """,
    )

    dbt_run = BashOperator(
        task_id='dbt_run',
        bash_command='cd /opt/airflow/transfers_dwh && dbt run --profiles-dir .',
    )

    dbt_test = BashOperator(
        task_id='dbt_test',
        bash_command='cd /opt/airflow/transfers_dwh && dbt test --profiles-dir .',
    )

    dbt_snapshot = BashOperator(
        task_id='dbt_snapshot',
        bash_command='cd /opt/airflow/transfers_dwh && dbt clean && dbt snapshot --profiles-dir .',
    )
    
    load_to_staging >> dbt_run >> dbt_snapshot >> dbt_test