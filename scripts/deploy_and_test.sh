#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-1433}"
SA_PASSWORD="${MSSQL_SA_PASSWORD:?MSSQL_SA_PASSWORD must be set}"

if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then
    SQLCMD_BIN="/opt/mssql-tools18/bin/sqlcmd"
    EXTRA_FLAGS=("-C")
elif [ -x /opt/mssql-tools/bin/sqlcmd ]; then
    SQLCMD_BIN="/opt/mssql-tools/bin/sqlcmd"
    EXTRA_FLAGS=()
elif command -v sqlcmd >/dev/null 2>&1; then
    SQLCMD_BIN="$(command -v sqlcmd)"
    EXTRA_FLAGS=("-C")
else
    echo "ERROR: sqlcmd binary not found." >&2
    exit 1
fi

run_sql() {
    local file="$1"
    echo "==> Running: $file"
    "$SQLCMD_BIN" -S "${DB_HOST},${DB_PORT}" -U sa -P "$SA_PASSWORD" "${EXTRA_FLAGS[@]}" -I -b -i "$file"
}

run_query() {
    local query="$1"
    "$SQLCMD_BIN" -S "${DB_HOST},${DB_PORT}" -U sa -P "$SA_PASSWORD" "${EXTRA_FLAGS[@]}" -I -b -Q "$query"
}

echo "==> Waiting for SQL Server at ${DB_HOST}:${DB_PORT}..."
ready=0
for i in $(seq 1 30); do
    if run_query "SELECT 1" >/dev/null 2>&1; then
        ready=1
        break
    fi
    echo "    Attempt $i/30: SQL Server not ready yet, waiting 2s..."
    sleep 2
done

if [ "$ready" -ne 1 ]; then
    echo "ERROR: SQL Server at ${DB_HOST}:${DB_PORT} did not become ready in time." >&2
    exit 1
fi

echo "==> Resetting existing mini_snapp database (if present)..."
run_query "IF DB_ID('mini_snapp') IS NOT NULL BEGIN ALTER DATABASE mini_snapp SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE mini_snapp; END"

echo ""
echo "============================================="
echo "STEP 1: Deploying Schemas, Tables & Indexes"
echo "============================================="
run_sql schema/01_create_database.sql
run_sql schema/02_create_schemas.sql
run_sql schema/03_core_table_v1.sql
run_sql schema/04_taxi_table_v1.sql
run_sql schema/05_food_tables_v1.sql
run_sql schema/06_indexes.sql

echo ""
echo "============================================="
echo "STEP 2: Deploying Programmability & BI Views"
echo "============================================="
run_sql programmability/core/core_v1_programmability.sql
run_sql programmability/taxi/taxi_v1_programmability.sql
run_sql programmability/food/food_functions_v1.sql
run_sql programmability/food/food_views_v1.sql
run_sql programmability/food/food_procedures_v1.sql
run_sql programmability/food/food_triggers_v1.sql
run_sql programmability/analytics/analytics_views_v1.sql

echo ""
echo "============================================="
echo "STEP 3: Running Automated SQL Test Suites"
echo "============================================="
run_sql tests/00_test_framework.sql
run_sql tests/01_core_full_test.sql
run_sql tests/02_taxi_full_test.sql
run_sql tests/03_food_full_test.sql
run_sql tests/04_analytics_full_test.sql

echo "==> Checking automated test assertions..."
run_query "IF EXISTS (SELECT 1 FROM mini_snapp.test.test_results WHERE result = 'FAIL') THROW 50001, 'One or more automated SQL tests failed!', 1;"

echo ""
echo "============================================="
echo "STEP 4: Loading Production Seed Data (USD)"
echo "============================================="
echo "==> Clearing test fixtures before seeding..."
run_query "EXEC mini_snapp.test.sp_reset_all_data;"
run_sql data/01_core_seed_v1.sql
run_sql data/02_taxi_seed_v1.sql
run_sql data/03_food_seed_v1.sql

echo ""
echo "============================================="
echo "SUCCESS: Database deployed, tested, and seeded!"
echo "============================================="
