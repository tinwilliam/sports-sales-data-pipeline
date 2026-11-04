from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.empty import EmptyOperator
from airflow.operators.python import PythonOperator
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

from load_json import load_json_to_postgres  # scripts/ est dans le PYTHONPATH
from generate_report import generate_report 

CONN_ID = "sports_postgres"


def sql_task(task_id, sql_file):
    return SQLExecuteQueryOperator(
        task_id=task_id,
        conn_id=CONN_ID,
        sql=sql_file,
        autocommit=True,
    )


with DAG(
    dag_id="sports_sales_pipeline",
    description="JSON -> exploded_products -> 3 tables KPI (full refresh)",
    start_date=datetime(2025, 1, 1),
    schedule="@daily",
    catchup=False,
    max_active_runs=1,
    template_searchpath=["/opt/airflow/sql"],
    default_args={"retries": 1, "retry_delay": timedelta(minutes=1)},
    tags=["sales", "etl", "postgres"],
) as dag:

    start = EmptyOperator(task_id="start_pipeline")

    create_tables = sql_task("create_tables", "ddl/01_create_tables.sql")

    load_json = PythonOperator(
        task_id="load_json",
        python_callable=load_json_to_postgres,
    )

    create_view = sql_task("create_transaction_summary", "transformations/02_transaction_summary.sql")

    quality_check = sql_task("check_data_quality", "quality/06_data_quality_checks.sql")

    store_sales = sql_task("store_sales_summary", "transformations/03_store_sales_summary.sql")
    daily_sales = sql_task("daily_sales_country_currency", "transformations/04_daily_sales_country_currency.sql")
    payment_analysis = sql_task("payment_method_analysis", "transformations/05_payment_method_analysis.sql")

    report = PythonOperator(
        task_id="generate_report",
        python_callable=generate_report,
    )
  

    end = EmptyOperator(task_id="end_pipeline")

    (
        start
        >> create_tables
        >> load_json
        >> create_view
        >> quality_check
        >> [store_sales, daily_sales, payment_analysis]
        >> report
        >> end
    )