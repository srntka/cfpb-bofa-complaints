-- Витрины для дашборда и анализа

-- Помесячные KPI: поток жалоб, изменение к прошлому месяцу,
-- доля ответов вовремя, доля денежных компенсаций (от закрытых), медиана времени передачи.
CREATE OR REPLACE VIEW v_monthly AS
WITH monthly AS (
    SELECT
        date_trunc('month', date_received AT TIME ZONE 'UTC')::date AS month,
        COUNT(*)                                                       AS complaints,
        AVG(timely_response::int)                                      AS share_timely,
        COUNT(*) FILTER (WHERE company_response LIKE 'Closed%')        AS closed,
        COUNT(*) FILTER (WHERE company_response = 'Closed with monetary relief') AS monetary_relief,
        percentile_cont(0.5) WITHIN GROUP (
            ORDER BY EXTRACT(EPOCH FROM date_sent_to_company - date_received) / 3600
        )                                                              AS median_delivery_hours
    FROM fact_complaints
    GROUP BY 1
)
SELECT
    month,
    complaints,
    LAG(complaints) OVER (ORDER BY month)                              AS complaints_prev_month,
    ROUND(
        (complaints - LAG(complaints) OVER (ORDER BY month))::numeric
        / NULLIF(LAG(complaints) OVER (ORDER BY month), 0), 4
    )                                                                  AS mom_change,
    ROUND(share_timely, 4)                                             AS share_timely,
    ROUND(monetary_relief::numeric / NULLIF(closed, 0), 4)             AS share_monetary_relief,
    ROUND(median_delivery_hours::numeric, 2)                           AS median_delivery_hours
FROM monthly;

-- Рейтинг штатов за весь период по абсолютному числу жалоб и на 100 тыс. жителей.
CREATE OR REPLACE VIEW v_state_rating AS
WITH by_state AS (
    SELECT
        s.state_code,
        s.state_name,
        s.population,
        COUNT(*) AS complaints
    FROM fact_complaints f
    JOIN dim_state s ON s.state_code = f.state
    GROUP BY s.state_code, s.state_name, s.population
)
SELECT
    state_code,
    state_name,
    population,
    complaints,
    ROUND(complaints * 100000.0 / population, 1)               AS complaints_per_100k,
    RANK() OVER (ORDER BY complaints * 1.0 / population DESC)  AS rank_per_100k,
    RANK() OVER (ORDER BY complaints DESC)                     AS rank_by_count
FROM by_state;

-- Жалобы по месяцам, группам продуктов и проблемам
CREATE OR REPLACE VIEW v_product_issue AS
SELECT
    date_trunc('month', f.date_received AT TIME ZONE 'UTC')::date AS month,
    p.product_group,
    p.product,
    i.issue,
    COUNT(*)                                                         AS complaints,
    COUNT(*) FILTER (WHERE f.company_response = 'Closed with monetary relief') AS monetary_relief,
    COUNT(*) FILTER (WHERE f.company_response LIKE 'Closed%')        AS closed
FROM fact_complaints f
JOIN dim_product p ON p.product_id = f.product_id
JOIN dim_issue   i ON i.issue_id   = f.issue_id
GROUP BY 1, p.product_group, p.product, i.issue;