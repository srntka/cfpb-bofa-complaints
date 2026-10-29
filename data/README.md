# Данные

Большие файлы в репозиторий не входят. Чтобы воспроизвести проект, положите в эту папку:

**complaints.csv** — выгрузка жалоб CFPB.
[consumerfinance.gov → Consumer Complaint Database](https://www.consumerfinance.gov/data-research/consumer-complaints/search/) → фильтры:
- Date received: 01/01/2022 – 09/30/2026
- Company: BANK OF AMERICA, NATIONAL ASSOCIATION

→ Download data → CSV → Filtered dataset. Переименовать файл в `complaints.csv`.

**NST-EST2025-ALLDATA.csv** — население штатов, U.S. Census Bureau, Vintage 2025.
[State Population Totals and Components of Change: 2020-2025](https://www.census.gov/data/datasets/time-series/demo/popest/2020s-state-total.html) → Datasets.

`us_states.csv` (уже в репозитории) собирается из файла Census скриптом `src/build_states.py`.
