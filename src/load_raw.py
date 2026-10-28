from pathlib import Path
import pandas as pd
from db import get_engine

RAW_CSV = Path(__file__).resolve().parents[1] / "data" / "complaints.csv"

COLUMNS = {
    "Date received": "date_received",
    "Product": "product",
    "Sub-product": "sub_product",
    "Issue": "issue",
    "Sub-issue": "sub_issue",
    "Company public response": "company_public_response",
    "Company": "company",
    "State": "state",
    "ZIP code": "zip_code",
    "Tags": "tags",
    "Submitted via": "submitted_via",
    "Date sent to company": "date_sent_to_company",
    "Company response to consumer": "company_response",
    "Timely response?": "timely_response",
    "Complaint ID": "complaint_id",
}


STATES_CSV = Path(__file__).resolve().parents[1] / "data" / "us_states.csv"

def load_raw(csv_path: Path = RAW_CSV) -> int:
    df = pd.read_csv(
        csv_path,
        dtype=str,
        keep_default_na=False,
        na_values=["", "None"],
    )
    missing = set(COLUMNS) - set(df.columns)
    if missing:
        raise ValueError(f"В выгрузке нет колонок: {missing}")

    df = df.rename(columns=COLUMNS)[list(COLUMNS.values())]

    df.to_sql(
        "stg_complaints",
        get_engine(),
        if_exists="replace",
        index=False,
        chunksize=2000,
        method="multi",
    )
    print(f"Загружено строк: {len(df):,}")
    return len(df)


def load_states(csv_path: Path = STATES_CSV) -> int:
    df = pd.read_csv(csv_path, dtype={"state_code": str, "state_name": str})
    df.to_sql("stg_states", get_engine(), if_exists="replace", index=False)
    print(f"Загружено штатов: {len(df)}")
    return len(df)

if __name__ == "__main__":
    load_raw()
    load_states()