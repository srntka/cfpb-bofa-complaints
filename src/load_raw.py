from pathlib import Path

import pandas as pd

from db import get_engine

DATA = Path(__file__).resolve().parents[1] / "data"

RENAME = {
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


def load_raw():
    # всё читаем текстом, "None" в выгрузке CFPB означает пропуск
    df = pd.read_csv(DATA / "complaints.csv", dtype=str,
                     keep_default_na=False, na_values=["", "None"])
    df = df.rename(columns=RENAME)[list(RENAME.values())]
    df.to_sql("stg_complaints", get_engine(), if_exists="replace",
              index=False, method="multi", chunksize=5000)
    print(f"stg_complaints: {len(df)} строк")


def load_states():
    df = pd.read_csv(DATA / "us_states.csv")
    df.to_sql("stg_states", get_engine(), if_exists="replace", index=False)
    print(f"stg_states: {len(df)} строк")


if __name__ == "__main__":
    load_raw()
    load_states()