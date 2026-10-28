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

-- 3. Допустимые значения timely_response (ожидаем только Yes / No)
SELECT
    timely_response,
    COUNT(*) AS complaints
FROM stg_complaints
GROUP BY timely_response
ORDER BY complaints DESC;

-- 4. Значения company_response (тип закрытия жалобы)
SELECT
    company_response,
    COUNT(*) AS complaints,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM stg_complaints
GROUP BY company_response
ORDER BY complaints DESC;

-- 5. Незакрытые жалобы по месяцам (ожидаем только последние месяцы)
SELECT
    LEFT(date_received, 7) AS month,
    COUNT(*) AS in_progress
FROM stg_complaints
WHERE company_response = 'In progress'
GROUP BY LEFT(date_received, 7)
ORDER BY month;

-- 6. Значения state: сколько разных кодов и нет ли нестандартных
SELECT
    state,
    COUNT(*) AS complaints
FROM stg_complaints
GROUP BY state
ORDER BY complaints ASC;

-- 7. Покрытие соединения жалоб со справочником штатов.
SELECT
    COUNT(*)                                   AS complaints,
    COUNT(s.state_code)                        AS matched_to_state,
    COUNT(*) - COUNT(s.state_code)             AS not_matched
FROM stg_complaints c
LEFT JOIN stg_states s ON s.state_code = c.state;