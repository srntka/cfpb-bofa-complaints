import pandas as pd
from statsmodels.tsa.seasonal import STL

from db import get_engine

pd.set_option("display.width", 200)
pd.set_option("display.max_columns", 10)
pd.set_option("display.max_colwidth", 60)


def load_monthly() -> pd.Series:
    df = pd.read_sql(
        "SELECT month, complaints FROM v_monthly ORDER BY month",
        get_engine(),
        parse_dates=["month"],
    )
    return df.set_index("month")["complaints"].asfreq("MS")

def detect_anomalies(
    series: pd.Series, threshold: float = 3.0, edge_months: int = 3
) -> pd.DataFrame:
    stl = STL(series, period=12, seasonal=13, seasonal_deg=0, robust=True).fit()

    expected = stl.trend + stl.seasonal
    resid = stl.resid
    scale = 1.4826 * (resid - resid.median()).abs().median()

    result = pd.DataFrame({
        "complaints": series,
        "expected": expected.round(1),
        "lower": (expected - threshold * scale).round(1),
        "upper": (expected + threshold * scale).round(1),
    })
    result["is_edge"] = result.index >= result.index[-edge_months]
    outside = (series > result["upper"]) | (series < result["lower"])
    result["is_anomaly"] = outside & ~result["is_edge"]
    return result

def load_by_segment(level: str = "product_group") -> pd.DataFrame:
    query = f"""
        SELECT month, {level} AS segment, SUM(complaints) AS complaints
        FROM v_product_issue
        GROUP BY month, {level}
    """
    df = pd.read_sql(query, get_engine(), parse_dates=["month"])
    return df.pivot_table(
        index="month", columns="segment", values="complaints", fill_value=0
    )

def decompose_spike(
    table: pd.DataFrame,
    month: pd.Timestamp,
    anomaly_months: list,
    baseline_months: int = 3,
) -> pd.DataFrame:
    prior = table[(table.index < month) & (~table.index.isin(anomaly_months))]
    baseline = prior.tail(baseline_months).mean()
    actual = table.loc[month]
    growth = actual - baseline

    out = pd.DataFrame({
        "baseline": baseline.round(1),
        "actual": actual,
        "growth": growth.round(1),
        "share_of_growth": (growth / growth.sum()).round(3),
    })
    return out.sort_values("growth", ascending=False)

def save_results(result: pd.DataFrame, drivers: pd.DataFrame) -> None:
    engine = get_engine()
    result.reset_index().to_sql("mart_monthly_anomalies", engine, if_exists="replace", index=False)
    drivers.to_sql("mart_spike_drivers", engine, if_exists="replace", index=False)
    print(f"Сохранено: {len(result)} месяцев, {len(drivers)} строк разложения")


def run_anomalies() -> None:
    result = detect_anomalies(load_monthly())
    anomaly_months = result.index[result["is_anomaly"]].tolist()

    parts = []
    for level in ["product_group", "issue"]:
        table = load_by_segment(level)
        for month in anomaly_months:
            top = decompose_spike(table, month, anomaly_months).head(5).reset_index()
            top.insert(0, "month", month)
            top.insert(1, "level", level)
            parts.append(top)

    drivers = pd.concat(parts, ignore_index=True)
    save_results(result, drivers)


if __name__ == "__main__":
    run_anomalies()