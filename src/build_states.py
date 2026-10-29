from pathlib import Path

import pandas as pd

DATA = Path(__file__).resolve().parents[1] / "data"

STATE_CODES = {
    "Alabama": "AL", "Alaska": "AK", "Arizona": "AZ", "Arkansas": "AR",
    "California": "CA", "Colorado": "CO", "Connecticut": "CT", "Delaware": "DE",
    "District of Columbia": "DC", "Florida": "FL", "Georgia": "GA", "Hawaii": "HI",
    "Idaho": "ID", "Illinois": "IL", "Indiana": "IN", "Iowa": "IA",
    "Kansas": "KS", "Kentucky": "KY", "Louisiana": "LA", "Maine": "ME",
    "Maryland": "MD", "Massachusetts": "MA", "Michigan": "MI", "Minnesota": "MN",
    "Mississippi": "MS", "Missouri": "MO", "Montana": "MT", "Nebraska": "NE",
    "Nevada": "NV", "New Hampshire": "NH", "New Jersey": "NJ", "New Mexico": "NM",
    "New York": "NY", "North Carolina": "NC", "North Dakota": "ND", "Ohio": "OH",
    "Oklahoma": "OK", "Oregon": "OR", "Pennsylvania": "PA", "Rhode Island": "RI",
    "South Carolina": "SC", "South Dakota": "SD", "Tennessee": "TN", "Texas": "TX",
    "Utah": "UT", "Vermont": "VT", "Virginia": "VA", "Washington": "WA",
    "West Virginia": "WV", "Wisconsin": "WI", "Wyoming": "WY",
}


def build_states():
    df = pd.read_csv(
        DATA / "NST-EST2025-ALLDATA.csv",
        usecols=["SUMLEV", "STATE", "NAME", "POPESTIMATE2025"],
        dtype={"SUMLEV": str, "STATE": str},
    )
    states = df[(df["SUMLEV"] == "040") & (df["STATE"] != "72")]
    states = states.assign(state_code=states["NAME"].map(STATE_CODES))
    assert states["state_code"].notna().all(), "не для всех штатов нашёлся код"

    result = (
        states.rename(columns={"NAME": "state_name", "POPESTIMATE2025": "population"})
        [["state_code", "state_name", "population"]]
        .sort_values("state_code")
    )
    result.to_csv(DATA / "us_states.csv", index=False)
    print(f"us_states.csv: {len(result)} штатов")


if __name__ == "__main__":
    build_states()