# Mini-Snapp DB

[![SQL Server 2022](https://img.shields.io/badge/SQL%20Server-2022%20(T--SQL)-CC2927?logo=microsoftsqlserver&logoColor=white)](https://www.microsoft.com/en-us/sql-server)
[![Docker Compose](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](./docker-compose.yml)
[![Database CI](https://img.shields.io/badge/GitHub%20Actions-CI-2088FF?logo=githubactions&logoColor=white)](./.github/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)

A multi-domain Microsoft SQL Server (`T-SQL`) database backend modeled after a ride-hailing and food-delivery super-app. Built in Third Normal Form (`3NF`), it runs two operational verticals (`taxi` and `food`) on top of a shared ledger, RBAC, wallet, promotion, and audit foundation (`core`).

All transactional state, concurrency locking, escrow settlement, cross-domain courier dispatch, and unit/integration tests live inside SQL Server and deploy in one command via Docker Compose.

---

## Quick Start

### Option 1: Docker Compose (Recommended)

Requires Docker with Compose v2.

```bash
cp .env.example .env
docker compose up --abort-on-container-exit --exit-code-from db-init
```

The `db-init` container waits for `sqlserver` to pass its health check, drops/recreates `mini_snapp`, and runs [scripts/deploy_and_test.sh](./scripts/deploy_and_test.sh) through four stages:

1. **Schema & Indexes**: Creates 4 schemas, 46 domain tables, and 23 nonclustered indexes (`schema/01..06`).
2. **Programmability & BI Views**: Deploys 15 functions, 29 views (including 6 executive BI views), 32 stored procedures, and 20 triggers.
3. **Automated Test Suites**: Loads `tests/00_test_framework.sql` and runs 93 assertions across `core`, `taxi`, `food`, and `analytics`. Fails the container if any row in `test.test_results` has `result = 'FAIL'`.
4. **Seed Data**: Resets test fixtures and loads realistic USD sample data (`data/01..03`).

Tear down containers and volumes when done:

```bash
docker compose down -v
```

### Option 2: Existing SQL Server Instance

If you already run SQL Server 2019+ with `sqlcmd` installed locally:

```bash
MSSQL_SA_PASSWORD="YourStrong!Password" DB_HOST="localhost" ./scripts/deploy_and_test.sh
```

---

## Architecture & Schema Overview

The database is split across three operational schemas (`core`, `taxi`, `food`) plus an isolated `test` schema. Both `taxi` and `food` settle payments against `core.user_wallets` and `core.transactions`, share promotions via `core.coupons` / `core.coupon_usages`, and link operationally when `food.trg_order_purchase` dispatches a `motorcycle` `cargo` offer into `taxi.ride_offers`.

| Schema | Responsibility | Tables | Indexes | Functions | Views | Procedures | Triggers |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| `core` | Users, RBAC, wallets, coupons, ledger, complaints, audit logs | 15 | 8 | 4 | 7 | 9 | 4 |
| `taxi` | Fleet, GPS pings, temporal pricing, offers, ride state machine | 13 | 8 | 4 | 7 | 15 | 7 |
| `food` | Brands, branches, schedules, ingredients, menus, carts, orders | 18 | 7 | 7 | 15 | 8 | 9 |
| `test` | Self-contained SQL assertion helpers (`test.test_results`) | 1 | — | — | — | 6 | — |
| **Total** | — | **47** | **23** | **15** | **29** | **38** | **20** |

### Entity-Relationship Diagrams

Schema diagrams are stored under [`docs/er_diagrams/`](./docs/er_diagrams) in both physical SVG/DBML formats (generated from `schema/03..05` via [scripts/generate_erd.py](./scripts/generate_erd.py)) and editable Draw.io files:

- **Core Schema (15 tables)**: [Physical ERD (SVG)](./docs/er_diagrams/core/core_schema_erd.svg) · [Conceptual ERD (.drawio)](./docs/er_diagrams/core/core_schema_erd.drawio)
- **Taxi Schema (13 tables)**: [Physical ERD (SVG)](./docs/er_diagrams/taxi/taxi_schema_erd.svg) · [Conceptual ERD (.drawio)](./docs/er_diagrams/taxi/taxi_schema_erd.drawio)
- **Food Schema (18 tables)**: [Physical ERD (SVG)](./docs/er_diagrams/food/food_schema_erd.svg) · [Conceptual ERD (.drawio)](./docs/er_diagrams/food/food_schema_erd.drawio)
- **Full Cross-Schema Model**: [mini_snapp.dbml](./docs/er_diagrams/mini_snapp.dbml) (ready to open in [dbdiagram.io](https://dbdiagram.io))

---

## Key Engineering Decisions

### 1. Concurrency-Safe Dispatch & Balance Guards
- `taxi.sp_respond_to_ride_offer` locks the candidate and driver rows using `WITH (UPDLOCK, ROWLOCK)` inside a transaction so two drivers cannot accept the same ride offer or double-book a busy driver under concurrent requests.
- Wallet debits in `taxi.sp_pay_for_ride` and `food.trg_order_purchase` perform an atomic balance check in the `WHERE` predicate (`WHERE user_id = @id AND balance >= @amount`) followed by `@@ROWCOUNT = 0` rollback, avoiding check-then-act race conditions.

### 2. Escrow Settlement, Commission Splits & Reversals
- **Prepaid Rides**: When `@is_prepaid = 1`, `taxi.sp_respond_to_ride_offer` calls `taxi.sp_pay_for_ride` immediately on acceptance. If the passenger later calls `taxi.sp_cancel_ride`, the full net fare is refunded into `core.user_wallets` with a `refund` ledger entry.
- **Temporal Commission Rates**: `core.fn_get_active_commission_rate` resolves historical split percentages using `effective_from` / `effective_to` intervals so changing platform rates never distorts historical settlements.
- **Order Cancellation Reversals**: `food.sp_cancel_order` inspects `food.fn_can_cancel_order` and reverses not only the customer's wallet charge, but also the credited shares in `food.branch_wallets` and `core.app_wallets`.

### 3. Cross-Domain Courier Dispatch
When items are inserted into `food.order_items`, `food.trg_order_purchase` handles financial settlement and cart cleanup in a single transaction, then—for non-takeout orders—calls `taxi.sp_create_ride_offer` with `vehicle_type = 'motorcycle'` and `service_type = 'cargo'` using Haversine coordinates between `food.branches` and `core.addresses`.

### 4. State Machines & Context-Aware Auditing
- Taxi rides (`scheduled -> to_origin -> to_destination -> completed`) and food orders (`pending -> confirmed -> preparing -> picked_up -> delivered`) reject stage-skipping and mutations out of terminal states (`completed`, `cancelled`, `disputed`).
- Triggers write structured JSON/value diffs into `core.core_logs`, `taxi.taxi_logs`, and `food.food_logs`, attributing actor IDs via SQL Server `SESSION_CONTEXT(N'current_user_id')`.

### 5. Least-Privilege Database Security
Defined in [schema/03_core_table_v1.sql](./schema/03_core_table_v1.sql) and granted per module:
- `app_service`: Allowed to `EXECUTE` stored procedures across `core`, `taxi`, and `food`, while direct `SELECT`, `INSERT`, `UPDATE`, and `DELETE` on underlying tables are explicitly denied.
- `readonly_analyst`: Granted `SELECT` exclusively on reporting and BI views (`vw_*`).
- `db_admin_role`: Granted `CONTROL` across application schemas for maintenance and migrations.

### 6. Targeted Indexing & Analytical BI Views
- [schema/06_indexes.sql](./schema/06_indexes.sql) adds 23 idempotent nonclustered indexes: filtered indexes (`WHERE driver_status = 'available'`, `WHERE ride_status IN (...)`, `WHERE is_active_now = 1`) for hot operational lookups, `INCLUDE` covering indexes to eliminate Key Lookups, and `effective_from DESC` indexes for temporal lookups.
- [programmability/analytics/analytics_views_v1.sql](./programmability/analytics/analytics_views_v1.sql) exposes 6 executive views (`vw_executive_daily_revenue`, `vw_coupon_campaign_roi`, `vw_customer_360_ltv`, `vw_fleet_operational_kpis`, `vw_branch_performance_leaderboard`, `vw_top_selling_menu_items`) built with pre-aggregated CTEs (preventing multi-domain join fan-out) and window functions (`LAG()`, `DENSE_RANK()`, running `SUM() OVER`).

---

## Automated Testing & CI

All 93 assertions run via a zero-dependency T-SQL assertion framework in [tests/00_test_framework.sql](./tests/00_test_framework.sql). Every suite resets database state cleanly via `test.sp_reset_all_data` before seeding isolated USD fixtures.

| Suite | File | Assertions | Coverage |
| :--- | :--- | :---: | :--- |
| Core | [tests/01_core_full_test.sql](./tests/01_core_full_test.sql) | 25 | Haversine distance, RBAC levels, coupon caps/expiry trigger, wallet charges, auth checks |
| Taxi | [tests/02_taxi_full_test.sql](./tests/02_taxi_full_test.sql) | 20 | Temporal fare pricing, single-active-vehicle trigger, dispatch, prepaid escrow, nested-transaction error propagation |
| Food | [tests/03_food_full_test.sql](./tests/03_food_full_test.sql) | 26 | Branch schedules, geo-range queries, overlapping discount guards, single-branch cart rule, split payout, courier dispatch, cancellation reversal |
| Analytics | [tests/04_analytics_full_test.sql](./tests/04_analytics_full_test.sql) | 22 | Multi-day revenue window functions, coupon ROI, Customer 360 LTV, SLA KPIs, `readonly_analyst` permissions, 23 index checks |

Every push and pull request to `main` or `master` runs [.github/workflows/ci.yml](./.github/workflows/ci.yml), which boots a clean SQL Server 2022 container, executes all four deployment/test/seed stages, and fails the workflow if any test assertion does not pass.

---

## Project Structure

```text
mini-snapp-db/
├── .github/workflows/ci.yml          # GitHub Actions pipeline (Docker + sqlcmd CI)
├── .env.example                      # Environment variable template for local SA password
├── docker-compose.yml                # SQL Server 2022 + automated db-init runner
├── CONVENTIONS.md                    # Naming rules, prefixes, USD & coordinate data types
├── LICENSE                           # MIT License
├── scripts/
│   ├── deploy_and_test.sh            # End-to-end deploy -> test -> assert -> seed script
│   └── generate_erd.py               # Generates DBML and Crow's-Foot SVG ERDs from DDL
├── schema/
│   ├── 01_create_database.sql        # Database creation
│   ├── 02_create_schemas.sql         # core, taxi, food schema definitions
│   ├── 03_core_table_v1.sql          # Identity, RBAC, wallets, transactions, coupons, roles
│   ├── 04_taxi_table_v1.sql          # Fleet, locations, pricing, ride offers, rides
│   ├── 05_food_tables_v1.sql         # Brands, branches, ingredients, menus, carts, orders
│   └── 06_indexes.sql                # 23 covering, filtered, and temporal indexes
├── programmability/
│   ├── core/core_v1_programmability.sql
│   ├── taxi/taxi_v1_programmability.sql
│   ├── food/
│   │   ├── food_functions_v1.sql
│   │   ├── food_views_v1.sql
│   │   ├── food_procedures_v1.sql
│   │   └── food_triggers_v1.sql
│   └── analytics/analytics_views_v1.sql
├── tests/
│   ├── 00_test_framework.sql         # Assertion procs & full DB reset procedure
│   ├── 01_core_full_test.sql
│   ├── 02_taxi_full_test.sql
│   ├── 03_food_full_test.sql
│   ├── 04_analytics_full_test.sql
│   ├── core_scenario/                # Interactive step-by-step core walk-throughs
│   └── taxi_scenario/                # Interactive step-by-step taxi walk-throughs
├── data/                             # USD production-like seed datasets
├── bulk_import/                      # 29 normalized CSV datasets for bulk loading
└── docs/
    ├── ARCHITECTURE.md               # Design reference (3NF, security, indexing, roadmap)
    └── er_diagrams/                  # Auto-generated DBML, Crow's-Foot SVGs & Draw.io models
```

For full object-level documentation, see [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) and [CONVENTIONS.md](./CONVENTIONS.md).

---

## Roadmap: Vector Database & Dietary AI Agents

The next planned phase extends `mini-snapp-db` into a hybrid relational + vector retrieval backend for tool-calling dietary and ordering agents:

1. **Sidecar Vector Index**: Sync dish titles, categories, normalized `food.food_ingredients` rows, and anonymized customer comments into a vector database (e.g., Qdrant or `pgvector`) keyed by `(food_id, menu_item_id)`.
2. **Semantic Matching + Deterministic Guardrails**: When a user asks an agent for meal suggestions tailored to a diet or craving (such as high-protein, low-carb, vegan, or nut-free), vector search proposes candidate dishes, and SQL Server enforces hard constraints:
   - Exact ingredient and allergen exclusion against `food.food_ingredients`.
   - Open-now checks (`food.fn_is_branch_open`), customer delivery radius (`food.fn_branches_within_distance`), and live discounted pricing (`food.fn_get_effective_menu_price`).
3. **Safe Agent Execution**: Confirmed picks are staged into the user's cart strictly through `food.sp_add_to_cart` under the `app_service` role, keeping single-branch cart rules, stock flags, and wallet checks intact.

---

## License

Released under the [MIT License](./LICENSE).
