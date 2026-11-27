# Database Naming & Engineering Conventions

## Schemas
- `core`: Shared identity, RBAC, wallets, coupons, transactions, complaints, and audit logs.
- `taxi`: Fleet management, driver locations, ride offers, dispatch state machine, and fare pricing.
- `food`: Brands, restaurant branches, menus, carts, food order fulfillment, and branch wallets.
- `test`: Automated SQL assertion framework and test results repository.

## Tables & Columns
- **Table Names**: Plural, lowercase, `snake_case` (e.g., `core.user_wallets`, `taxi.ride_offers`).
- **Primary Keys**: Singular `<entity>_id` (e.g., `user_id`, `ride_id`, `branch_id`).
- **Foreign Keys**: Match the referenced primary key name wherever unambiguous, or `<role>_id` when referencing `core.users(user_id)` (e.g., `passenger_id`, `customer_id`, `reporter_id`).
- **Boolean Flags**: `BIT` prefixed with `is_` or `has_` (e.g., `is_active`, `is_blocked`, `is_prepaid`, `is_takeout`).

## Programmability Prefixes
- **Views**: `vw_` (e.g., `core.vw_active_coupons`)
- **Functions**: `fn_` (e.g., `core.fn_calculate_distance_km`)
- **Stored Procedures**: `sp_` (e.g., `taxi.sp_respond_to_ride_offer`)
- **Triggers**: `trg_<table>_<event>` (e.g., `core.trg_users_after_insert`)

## Constraints & Indexes
- **Primary Key**: `pk_<table>`
- **Foreign Key**: `fk_<table>_<column>`
- **Unique**: `uq_<table>_<column(s)>`
- **Check**: `chk_<table>_<rule>`
- **Nonclustered Indexes**: `ix_<table>_<columns_or_purpose>` (covering `INCLUDE` and filtered `WHERE` clauses defined in `schema/06_indexes.sql`)

## Standard Data Types
- **Currency (USD)**: `DECIMAL(10,2)`
- **Percentages**: `DECIMAL(5,2)`
- **Brand Commission Fraction**: `DECIMAL(5,4)`
- **Ratings**: `DECIMAL(3,2)` (`0.00` to `5.00`)
- **Latitude / Longitude**: `DECIMAL(10,8)` / `DECIMAL(11,8)`
- **Person Names / Usernames**: `VARCHAR(50)`
- **Email Addresses**: `VARCHAR(100)`
- **Password Hashes**: `VARCHAR(255)`
- **Phone Numbers / National IDs**: `VARCHAR(15)` to `VARCHAR(20)`
- **License Plates**: `VARCHAR(20)`
- **Status / Type Enumerations**: `VARCHAR(15)` to `VARCHAR(20)`
- **Free-form Descriptions / JSON Payloads**: `NVARCHAR(MAX)`
