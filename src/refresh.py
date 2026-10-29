from pathlib import Path

from sqlalchemy import text

from anomalies import run_anomalies
from db import get_engine
from load_raw import load_raw, load_states

SQL = Path(__file__).resolve().parents[1] / "sql"


def run_sql(name):
    conn = get_engine().raw_connection()
    try:
        with conn.cursor() as cur:
            cur.execute((SQL / name).read_text(encoding="utf-8"))
        conn.commit()
    finally:
        conn.close()
    print(f"{name}: ok")


def count(query):
    with get_engine().connect() as conn:
        return conn.execute(text(query)).scalar()


def check_staging():
    dupes = count("SELECT COUNT(*) - COUNT(DISTINCT complaint_id) FROM stg_complaints")
    assert dupes == 0, f"дубли complaint_id: {dupes}"

    bad_dates = count("""
        SELECT COUNT(*) FROM stg_complaints
        WHERE date_sent_to_company::timestamptz < date_received::timestamptz
    """)
    assert bad_dates == 0, f"передача в банк раньше получения: {bad_dates}"


def check_model():
    lost = count("""
        SELECT (SELECT COUNT(*) FROM stg_complaints)
             - (SELECT COUNT(*) FROM fact_complaints)
    """)
    assert lost == 0, f"при построении факта потеряно строк: {lost}"


if __name__ == "__main__":
    load_raw()
    load_states()
    check_staging()
    run_sql("01_schema.sql")
    check_model()
    run_sql("03_views.sql")
    run_anomalies()
    print("готово")