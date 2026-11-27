# Mini-Snapp Database Architecture & Programmability Reference

## 1. System Overview

**Mini-Snapp DB** is a modular, multi-domain relational database system built for **Microsoft SQL Server (T-SQL)** simulating a multi-service super-app combining ride-hailing/courier dispatch (`taxi`) and restaurant food delivery (`food`) on top of a unified identity, wallet, RBAC, promotion, and audit engine (`core`).

### Schema Boundaries
| Schema | Responsibility | Core Entities |
| :--- | :--- | :--- |
| `core` | Identity, RBAC hierarchy, user/platform wallets, coupons, payment ledger, complaints, audit logs | `users`, `roles`, `permissions`, `user_wallets`, `app_wallets`, `transactions`, `coupons`, `coupon_usages`, `addresses`, `complaints`, `commission_rates`, `core_logs` |
| `taxi` | Fleet management, live driver coordinates, temporal pricing, Haversine dispatch, ride state machine | `drivers`, `vehicles`, `vehicle_type_services`, `driver_wallets`, `driver_locations`, `pricing_parameters`, `ride_offers`, `ride_offer_candidates`, `rides`, `ride_payments`, `passenger_stats`, `taxi_logs` |
| `food` | Restaurant brands/branches, menus, item discounts, carts, order lifecycle, automatic courier dispatch | `brands`, `brand_owners`, `branches`, `branch_owners`, `restaurant_staff`, `branch_wallets`, `work_schedules`, `foods`, `food_ingredients`, `menu_items`, `menu_discounts`, `cart_items`, `food_orders`, `order_items`, `order_payments`, `customer_stats`, `food_logs` |
| `test` | Self-contained SQL unit and integration testing assertions | `test_results` |

---

## 2. Normalization & Relational Integrity (3NF)

Every entity across `core`, `taxi`, and `food` adheres to **Third Normal Form (3NF)**:
- **1NF (Atomicity)**: Multi-valued attributes are decomposed into dedicated child tables with primary keys and foreign keys — e.g., `core.saved_accounts` (multiple bank cards per user), `taxi.driver_secondary_phones`, `food.business_phones`, and `food.food_ingredients`.
- **2NF (Full Functional Dependency)**: Composite relationships (`core.role_permissions`, `taxi.vehicle_type_services`, `food.menu_items`, `food.order_items`) store only attributes dependent on the whole relationship key; invariant entity attributes (such as `food.foods.category` or `taxi.drivers.average_rating`) remain on their parent tables.
- **3NF (No Transitive Dependencies)**:
  - Role names and hierarchy levels live in `core.roles` rather than `core.users`.
  - Vehicle attributes (`license_plate`, `vehicle_type`, `is_active_now`) are normalized into `taxi.vehicles` rather than `taxi.drivers`.
  - Brand-level commission rates live on `food.brands` (with platform-wide temporal defaults in `core.commission_rates`) rather than `food.menu_items`.
  - Controlled snapshots (`food.order_items.current_price` and `taxi.rides.calculated_price`) intentionally preserve point-in-time financial immutability when menu prices or fare parameters change later.

---

## 3. Database-Level Security Model (Principle of Least Privilege)

Defined in `schema/03_core_table_v1.sql` and schema programmability scripts:
- **`app_service`**: Application backend role. Granted `EXECUTE` on `core`, `taxi`, and `food` schemas while explicitly `DENY`ing direct `SELECT`, `INSERT`, `UPDATE`, and `DELETE` on underlying base tables. All mutations pass through validated, transactional stored procedures.
- **`readonly_analyst`**: BI/reporting role. Granted `SELECT` exclusively on curated analytical and operational views (`vw_*`) across `core`, `taxi`, and `food`.
- **`db_admin_role`**: Privileged schema maintenance role with `CONTROL` permissions.

---

## 4. Programmability Catalog

### 4.1 Functions (`fn_*`)
- **Core**:
  - `core.fn_calculate_distance_km`: `SCHEMABINDING` Haversine great-circle distance calculator in kilometers.
  - `core.fn_validate_coupon`: Validates coupon existence, active flag, expiration timestamp, global usage cap, minimum order value, and per-user single-use constraint.
  - `core.fn_has_minimum_role_level`: Evaluates user RBAC `hierarchy_level` against a required threshold.
  - `core.fn_get_active_commission_rate`: Inline TVF supporting point-in-time (`@check_date`) commission lookup across `effective_from` / `effective_to` windows.
- **Taxi**:
  - `taxi.fn_get_active_pricing_parameter`: Temporal fare parameter lookup per `(vehicle_type, service_type)`.
  - `taxi.fn_calculate_ride_price`: Computes `base_fare + (distance_km * price_per_km) + (duration_minutes * price_per_minute)`.
  - `taxi.fn_vehicle_supports_service`: Verifies vehicle-to-service capability (`passenger` vs `cargo`).
  - `taxi.fn_find_nearest_available_drivers`: Inline TVF returning top-N nearest `available` drivers with an active matching vehicle ordered by Haversine distance.
- **Food**:
  - `food.fn_haversine_km` & `food.fn_branches_within_distance`: Geospatial restaurant discovery bounded by both customer search radius and branch `max_delivery_distance`.
  - `food.fn_is_branch_open`: Checks branch `work_schedules` against day-of-week and time-of-day.
  - `food.fn_get_effective_menu_price`: Applies active item-level percentage/flat discounts with a `0.00` floor.
  - `food.fn_calculate_cart_total`, `food.fn_calculate_order_total`, `food.fn_can_cancel_order`.

### 4.2 Stored Procedures (`sp_*`)
- **Core**: `sp_register_user` (atomic user + wallet creation), `sp_charge_wallet`, `sp_assign_admin_role`, `sp_apply_coupon` (atomic validation + discount calculation + target order/ride update), `sp_check_user_exists`, `sp_verify_login`, `sp_get_user_profile`, `sp_get_available_coupons`, `sp_write_log`.
- **Taxi**: `sp_register_driver`, `sp_register_vehicle`, `sp_create_ride_offer`, `sp_respond_to_ride_offer` (concurrency-safe with `UPDLOCK, ROWLOCK` and upfront escrow deduction for prepaid rides), `sp_pay_for_ride`, `sp_update_ride_status` (strict state-machine transitions), `sp_start_ride_to_origin`, `sp_start_ride_to_destination`, `sp_complete_ride` (escrow settlement & commission split), `sp_cancel_ride` (automatic prepaid refund), `sp_rate_ride`, and read APIs.
- **Food**: `sp_add_to_cart` (enforces single-branch cart rule), `sp_clear_cart`, `sp_cancel_order` (stage-aware cancellation + full customer refund + merchant/platform payout reversal), `sp_set_branch_schedule` (`MERGE` upsert), `sp_create_menu_discount`, `sp_assign_restaurant_staff`, `sp_get_available_branches_for_customer`, `sp_write_log`.

### 4.3 Triggers (`trg_*`)
- **Cross-Domain Order Fulfillment (`food.trg_order_purchase`)**: Automatically computes order totals and top-up deltas when `food.order_items` are inserted, verifies sufficient wallet balance, records ledger transactions, splits commission between `food.branch_wallets` and `core.app_wallets`, clears the customer's cart, and dispatches a `motorcycle` `cargo` ride offer into the `taxi` schema for delivery orders.
- **State Machine & Data Integrity**: `food.trg_food_orders_status_validate` (enforces sequential status progression), `food.trg_food_orders_timestamp_autofill`, `food.trg_menu_discounts_validate` (blocks overlapping active discount windows), `food.trg_cart_items_validate`, `food.trg_branches_after_insert_create_wallet`, `taxi.trg_vehicles_enforce_single_active`, `core.trg_coupons_after_update` (auto-deactivates exhausted coupons).
- **Dynamic Rating & Audit Triggers**: `taxi.trg_rides_update_metrics` (incremental rating & gamification points for drivers and passengers), plus JSON/structured audit triggers across `core.core_logs`, `taxi.taxi_logs`, and `food.food_logs`.

### 4.4 Executive & Managerial BI Views (`programmability/analytics/analytics_views_v1.sql`)
All analytical views are built with independent CTE pre-aggregations (preventing multi-domain join fan-out) and SQL Server Window Functions (`SUM() OVER`, `LAG() OVER`, `DENSE_RANK() OVER`), and are exposed exclusively to `readonly_analyst`:
- **`core.vw_executive_daily_revenue`**: Daily Taxi + Food GMV, promo discounts, net revenue, estimated platform commission, day-over-day `LAG()`, and running cumulative revenue.
- **`core.vw_coupon_campaign_roi`**: Per-coupon utilization percentage, cross-domain redemption breakdown, total discount subsidy, and revenue-to-subsidy ROI ratio.
- **`core.vw_customer_360_ltv`**: Unified customer lifetime value across Ride-Hailing and Food Delivery, identifying `is_super_app_user` cohorts and `DENSE_RANK()` spend tiers.
- **`taxi.vw_fleet_operational_kpis`**: Supply/demand metrics per `(vehicle_type, service_type)`, cancellation rates, average trip distance, and completed GMV.
- **`food.vw_branch_performance_leaderboard`**: Branch fulfillment rate, delivered GMV, average cooking duration, kitchen SLA on-time percentage, and intra-city / intra-brand `DENSE_RANK()` leaderboards.
- **`food.vw_top_selling_menu_items`**: Non-cancelled item sales volume and revenue ranked within each food category.

---

## 5. Indexing & Query Optimization Strategy (`schema/06_indexes.sql`)

All secondary indexes are consolidated in an idempotent script (`schema/06_indexes.sql`) using three targeted SQL Server optimization patterns across 23 nonclustered indexes:
1. **Filtered Indexes (Hot-Path Isolation)**: Narrow `WHERE` predicates keep index pages tiny and eliminate cold/terminal rows from hot operational queries:
   - `ix_drivers_available` (`WHERE driver_status = 'available'`) and `ix_vehicles_owner_active` (`WHERE is_active_now = 1`) accelerate nearest-driver matching.
   - `ix_rides_active` (`WHERE ride_status IN ('scheduled', 'to_origin', 'to_destination')`) and `ix_ride_offer_candidates_driver_pending` (`WHERE response_status = 'pending'`) optimize real-time dispatch polling.
   - `ix_branches_active_geo`, `ix_menu_discounts_active`, `ix_coupons_active_lookup`, `ix_complaints_open_queue`, and polymorphic `ix_coupon_usages_order_id` / `ix_coupon_usages_ride_id` filter out inactive or null records.
2. **Covering Indexes (`INCLUDE` Columns)**: Queries powering read APIs and BI views (such as `ix_transactions_user_created`, `ix_rides_passenger_history`, `ix_rides_driver_completed`, `ix_food_orders_customer_created`, `ix_food_orders_branch_status`, and `ix_order_items_order_id`) include all projected columns at the leaf level to eliminate expensive Key Lookups.
3. **Temporal Lookup Indexes**: Descending `effective_from DESC` keys on `ix_commission_rates_lookup` and `ix_pricing_parameters_lookup` support single-seek point-in-time (`TOP 1`) lookups.

---

## 6. Planned Extension: Hybrid Vector Search & Dietary AI Agents

The current SQL Server schema serves as the transactional system of record for menus, ingredient breakdowns (`food.food_ingredients`), live branch hours (`food.work_schedules`), delivery radii (`food.branches.max_delivery_distance`), pricing, and wallet settlement. The next planned milestone pairs this relational core with a sidecar vector database (such as Qdrant or PostgreSQL with `pgvector`) to support agentic food recommendations:

1. **Dual-Store Indexing**: An ingestion pipeline embeds dish names, categories, normalized `food.food_ingredients` rows, and anonymized order feedback (`food.food_orders.comment`) into a vector index keyed by `(food_id, menu_item_id)`.
2. **Semantic Retrieval + Deterministic Filtering**: An AI agent interprets a user's dietary goal or craving (e.g., high-protein, plant-based, nut-free, spicy) via vector similarity search, then passes candidate `food_id` values back to SQL Server for strict verification:
   - Exact allergen and ingredient exclusion against `food.food_ingredients`.
   - Spatial reachability and live operating hours via `food.fn_branches_within_distance` and `food.fn_is_branch_open`.
   - Real-time item availability and discounted pricing via `food.fn_get_effective_menu_price`.
3. **Controlled Tool Execution**: Once a user confirms a recommendation, the agent interacts with SQL Server exclusively under the existing `app_service` role (using `food.sp_add_to_cart` and transactional order workflows) rather than issuing raw table queries, preserving all wallet, discount, and single-branch cart invariants.
