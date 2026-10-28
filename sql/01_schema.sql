DROP TABLE IF EXISTS fact_complaints;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_issue;
DROP TABLE IF EXISTS dim_state;

CREATE TABLE dim_product (
    product_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product      text NOT NULL,
    sub_product  text NOT NULL,
    UNIQUE (product, sub_product)
);

INSERT INTO dim_product (product, sub_product)
SELECT DISTINCT
    product,
    COALESCE(sub_product, '(not specified)')
FROM stg_complaints;

CREATE TABLE dim_issue (
    issue_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    issue      text NOT NULL,
    sub_issue  text NOT NULL,
    UNIQUE (issue, sub_issue)
);

INSERT INTO dim_issue (issue, sub_issue)
SELECT DISTINCT
    COALESCE(issue, '(not specified)'),
    COALESCE(sub_issue, '(not specified)')
FROM stg_complaints;

CREATE TABLE dim_state (
    state_code  char(2) PRIMARY KEY,
    state_name  text    NOT NULL,
    population  integer NOT NULL CHECK (population > 0)
);

INSERT INTO dim_state (state_code, state_name, population)
SELECT state_code, state_name, population
FROM stg_states;

CREATE TABLE fact_complaints (
    complaint_id          bigint PRIMARY KEY,
    date_received         timestamptz NOT NULL,
    date_sent_to_company  timestamptz NOT NULL,
    product_id            integer NOT NULL REFERENCES dim_product (product_id),
    issue_id              integer NOT NULL REFERENCES dim_issue (issue_id),
    state                 text,
    zip_code              text,
    tags                  text,
    submitted_via         text NOT NULL,
    company_response      text NOT NULL,
    timely_response       boolean NOT NULL
);

INSERT INTO fact_complaints
SELECT
    s.complaint_id::bigint,
    s.date_received::timestamptz,
    s.date_sent_to_company::timestamptz,
    p.product_id,
    i.issue_id,
    s.state,
    s.zip_code,
    s.tags,
    s.submitted_via,
    s.company_response,
    s.timely_response = 'Yes'
FROM stg_complaints s
JOIN dim_product p
  ON p.product = s.product
 AND p.sub_product = COALESCE(s.sub_product, '(not specified)')
JOIN dim_issue i
  ON i.issue = COALESCE(s.issue, '(not specified)')
 AND i.sub_issue = COALESCE(s.sub_issue, '(not specified)');