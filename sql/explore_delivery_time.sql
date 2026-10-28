-- Исследование: время передачи жалобы из CFPB в банк.

-- 1. Распределение времени передачи.
WITH delays AS (
    SELECT date_sent_to_company::timestamptz - date_received::timestamptz AS delay
    FROM stg_complaints
)
SELECT
    AVG(delay)                                               AS avg_delay,
    percentile_cont(0.5)  WITHIN GROUP (ORDER BY delay)      AS median,
    percentile_cont(0.9)  WITHIN GROUP (ORDER BY delay)      AS p90,
    percentile_cont(0.99) WITHIN GROUP (ORDER BY delay)      AS p99,
    COUNT(*) FILTER (WHERE delay > interval '30 days')       AS over_30_days
FROM delays;


-- 2. Время передачи по каналам.
-- Referral медленный (медиана 22 ч), но 81% передач >30 дней - Web.
WITH delays AS (
    SELECT
        submitted_via,
        date_sent_to_company::timestamptz - date_received::timestamptz AS delay
    FROM stg_complaints
)
SELECT
    submitted_via,
    COUNT(*)                                                   AS complaints,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY delay)         AS median,
    ROUND(100.0 * COUNT(*) FILTER (WHERE delay > interval '1 day') / COUNT(*), 1) AS pct_over_1_day,
    COUNT(*) FILTER (WHERE delay > interval '30 days')         AS over_30_days
FROM delays
GROUP BY submitted_via
ORDER BY complaints DESC;


-- 3. Месяцы с наибольшей долей передач >30 дней.
-- 8 из 10 - 2025 год.
WITH delays AS (
    SELECT
        LEFT(date_received, 7) AS month,
        date_sent_to_company::timestamptz - date_received::timestamptz AS delay
    FROM stg_complaints
)
SELECT
    month,
    COUNT(*)                                            AS complaints,
    COUNT(*) FILTER (WHERE delay > interval '30 days')  AS over_30_days,
    ROUND(100.0 * COUNT(*) FILTER (WHERE delay > interval '30 days') / COUNT(*), 2) AS pct_over_30_days
FROM delays
GROUP BY month
ORDER BY pct_over_30_days DESC
LIMIT 10;


-- 4. Поток жалоб и доля передач >30 дней по годам.
-- 2025: поток +34%, доля задержек x10.
WITH delays AS (
    SELECT
        LEFT(date_received, 4) AS year,
        date_sent_to_company::timestamptz - date_received::timestamptz AS delay
    FROM stg_complaints
)
SELECT
    year,
    COUNT(*)                                            AS complaints,
    COUNT(*) FILTER (WHERE delay > interval '30 days')  AS over_30_days,
    ROUND(100.0 * COUNT(*) FILTER (WHERE delay > interval '30 days') / COUNT(*), 2) AS pct_over_30_days
FROM delays
GROUP BY year
ORDER BY year;


-- 5. Корреляция месячного потока и доли задержек (без 3 последних неполных месяцев).
-- r = 0,43.
WITH monthly AS (
    SELECT
        LEFT(date_received, 7) AS month,
        COUNT(*) AS complaints,
        100.0 * COUNT(*) FILTER (
            WHERE date_sent_to_company::timestamptz - date_received::timestamptz > interval '30 days'
        ) / COUNT(*) AS pct_over_30_days
    FROM stg_complaints
    WHERE date_received < '2026-07'
    GROUP BY LEFT(date_received, 7)
)
SELECT
    COUNT(*)                                                AS months,
    ROUND(corr(complaints, pct_over_30_days)::numeric, 2)  AS correlation
FROM monthly;