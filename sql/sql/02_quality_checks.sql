-- 1. Проверка дат (ожидается 0)
SELECT
    COUNT(*) FILTER (WHERE date_received        !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') AS bad_received,
    COUNT(*) FILTER (WHERE date_sent_to_company !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') AS bad_sent
FROM stg_complaints;

-- 2. Логика дат + проверка на выбросы с длительной отправкой
SELECT
    COUNT(*) FILTER (WHERE date_sent_to_company::timestamptz <  date_received::timestamptz) AS sent_before_received,
    MIN(date_sent_to_company::timestamptz - date_received::timestamptz) AS min_delay,
    MAX(date_sent_to_company::timestamptz - date_received::timestamptz) AS max_delay
FROM stg_complaints;

-- 3. Распределение времени передачи жалоб
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

-- 4. Время передачи исходя из типа канала
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

