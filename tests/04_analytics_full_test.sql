USE mini_snapp;
GO
SET NOCOUNT ON;
GO

-- =============================================
-- AUTOMATED TEST SUITE 04: ANALYTICAL BI VIEWS & INDEXES
-- Prerequisite: schema/06_indexes.sql,
--               programmability/analytics/analytics_views_v1.sql,
--               tests/00_test_framework.sql
-- =============================================

EXEC test.sp_reset_all_data;
DELETE FROM test.test_results WHERE test_suite = 'analytics';
GO

-- PHASE 1: SEED CONTROLLED CROSS-DOMAIN BI FIXTURES (USD)

INSERT INTO core.roles (role_name, role_description, hierarchy_level) VALUES
('customer', 'Customer', 1),
('driver',   'Driver',   2);

DECLARE @r_cust INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @r_driv INT = (SELECT role_id FROM core.roles WHERE role_name = 'driver');

INSERT INTO core.app_wallets (total_balance) VALUES (0.00);

INSERT INTO core.commission_rates (service_type, driver_share, restaurant_share, app_share, effective_from) VALUES
('food', 15.00, 75.00, 10.00, DATEADD(MONTH, -1, GETDATE())),
('taxi', 80.00, NULL,  20.00, DATEADD(MONTH, -1, GETDATE()));

INSERT INTO core.users (username, password_hash, registration_phone, role_id) VALUES
('bi_super_user',    'hash', '09190000001', @r_cust),
('bi_food_user',     'hash', '09190000002', @r_cust),
('bi_driver_user',   'hash', '09190000003', @r_driv);

INSERT INTO core.user_wallets (user_id, balance)
SELECT user_id,
    CASE username
        WHEN 'bi_super_user' THEN 200.00
        WHEN 'bi_food_user'  THEN 100.00
        ELSE 0.00
    END
FROM core.users;

DECLARE @u_super  INT = (SELECT user_id FROM core.users WHERE username = 'bi_super_user');
DECLARE @u_food   INT = (SELECT user_id FROM core.users WHERE username = 'bi_food_user');
DECLARE @u_driver INT = (SELECT user_id FROM core.users WHERE username = 'bi_driver_user');

INSERT INTO taxi.vehicle_type_services (vehicle_type, service_type) VALUES ('economy', 'passenger');
INSERT INTO taxi.pricing_parameters (vehicle_type, service_type, base_fare, price_per_km, price_per_minute)
VALUES ('economy', 'passenger', 10.00, 2.00, 0.50);

INSERT INTO taxi.drivers (user_id, national_id, date_of_birth, driver_status, gender)
VALUES (@u_driver, '0077889900', '1993-06-15', 'available', 'male');
DECLARE @drv_id INT = SCOPE_IDENTITY();

INSERT INTO taxi.driver_wallets (driver_id, balance) VALUES (@drv_id, 0.00);
INSERT INTO taxi.vehicles (owner_id, vehicle_type, license_plate, color, model_name, is_active_now)
VALUES (@drv_id, 'economy', '55-A-100', 'White', 'Peugeot 206', 1);
DECLARE @veh_id INT = SCOPE_IDENTITY();

DECLARE @day1 DATETIME = DATEADD(DAY, -2, CAST(CAST(GETDATE() AS DATE) AS DATETIME));
DECLARE @day2 DATETIME = DATEADD(DAY, -1, CAST(CAST(GETDATE() AS DATE) AS DATETIME));

-- Completed ride ($25.00 net, $5.00 platform fee at 20%)
INSERT INTO taxi.rides (
    passenger_id, driver_id, vehicle_id,
    origin_latitude, origin_longitude, destination_latitude, destination_longitude,
    estimated_distance, calculated_price, allocated_discount, service_type,
    ride_status, ride_payment_status, requested_at, accepted_at, started_at, completed_at
) VALUES (
    @u_super, @drv_id, @veh_id,
    35.70000000, 51.40000000, 35.73000000, 51.43000000,
    5.00, 25.00, 0.00, 'passenger',
    'completed', 'paid',
    DATEADD(HOUR, 10, @day1), DATEADD(MINUTE, 601, @day1), DATEADD(MINUTE, 605, @day1), DATEADD(MINUTE, 620, @day1)
);

-- Cancelled ride (gives 50.00% cancellation rate for economy/passenger)
INSERT INTO taxi.rides (
    passenger_id, driver_id, vehicle_id,
    origin_latitude, origin_longitude, destination_latitude, destination_longitude,
    estimated_distance, calculated_price, allocated_discount, service_type,
    ride_status, ride_payment_status, requested_at, accepted_at, cancelled_at, cancel_reason
) VALUES (
    @u_super, @drv_id, @veh_id,
    35.70000000, 51.40000000, 35.72000000, 51.42000000,
    3.00, 15.00, 0.00, 'passenger',
    'cancelled', 'pending',
    DATEADD(HOUR, 10, @day2), DATEADD(MINUTE, 601, @day2), DATEADD(MINUTE, 603, @day2), 'Rider cancelled'
);

-- Food catalog & coupon
INSERT INTO food.brands (name, commission_rate) VALUES ('Analytics Grill', 0.1500);
DECLARE @br_id INT = SCOPE_IDENTITY();

INSERT INTO food.branches (brand_id, province, city, street, latitude, longitude, food_type, max_delivery_distance, is_active, rating)
VALUES (@br_id, 'Tehran', 'Tehran', 'Jordan Blvd', 35.72000000, 51.41000000, 'Kabab', 8.00, 1, 4.70);
DECLARE @bch_id INT = SCOPE_IDENTITY();

INSERT INTO food.foods (brand_id, name, category) VALUES (@br_id, 'Royal Kabab', 'Kabab');
DECLARE @fd_id INT = SCOPE_IDENTITY();

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, estimated_prep_time)
VALUES (@bch_id, @fd_id, 20.00, 1, 25);
DECLARE @mi_id INT = SCOPE_IDENTITY();

INSERT INTO core.coupons (code, [percentage], amount, min_requirement, max_cap, current_usage, max_usage, is_active)
VALUES ('BI_SAVE5', NULL, 5.00, 10.00, NULL, 0, 10, 1);

-- Food Order 1 on Day 1: 2 * $20.00 = $40.00, then $5.00 coupon applied -> $35.00 net, on-time cooking (20 <= 25 min)
INSERT INTO food.food_orders (
    customer_id, branch_id, delivery_fee, final_price, allocated_discount, is_takeout,
    created_at, confirmed_at, cooking_completed_at, estimated_cooking_time, delivered_at, status
) VALUES (
    @u_super, @bch_id, 0.00, 0.00, 0.00, 1,
    DATEADD(HOUR, 12, @day1), DATEADD(MINUTE, 722, @day1), DATEADD(MINUTE, 742, @day1), 25, DATEADD(MINUTE, 760, @day1), 'delivered'
);
DECLARE @ord1 INT = SCOPE_IDENTITY();

INSERT INTO food.order_items (order_id, menu_item_id, quantity, current_price)
VALUES (@ord1, @mi_id, 2, 20.00);

EXEC core.sp_apply_coupon @coupon_code = 'BI_SAVE5', @user_id = @u_super, @order_amount = 40.00, @order_id = @ord1;

-- Food Order 2 on Day 2: 1 * $20.00 = $20.00 net, late cooking (30 > 25 min) -> 50.00% branch SLA
INSERT INTO food.food_orders (
    customer_id, branch_id, delivery_fee, final_price, allocated_discount, is_takeout,
    created_at, confirmed_at, cooking_completed_at, estimated_cooking_time, delivered_at, status
) VALUES (
    @u_food, @bch_id, 0.00, 0.00, 0.00, 1,
    DATEADD(HOUR, 12, @day2), DATEADD(MINUTE, 722, @day2), DATEADD(MINUTE, 752, @day2), 25, DATEADD(MINUTE, 770, @day2), 'delivered'
);
DECLARE @ord2 INT = SCOPE_IDENTITY();

INSERT INTO food.order_items (order_id, menu_item_id, quantity, current_price)
VALUES (@ord2, @mi_id, 1, 20.00);
GO

-- PHASE 2: ASSERT ANALYTICAL VIEWS & INDEX DEPLOYMENT

PRINT '=============================================';
PRINT 'STARTING TEST SUITE: analytics';
PRINT '=============================================';
GO

DECLARE @d1 DATE = DATEADD(DAY, -2, CAST(GETDATE() AS DATE));
DECLARE @d2 DATE = DATEADD(DAY, -1, CAST(GETDATE() AS DATE));

-- 1. Executive Daily Revenue (Window Functions: Cumulative & LAG)
DECLARE @food_d1_net DECIMAL(18,2), @food_d2_net DECIMAL(18,2), @food_d2_prev DECIMAL(18,2), @food_d2_cum DECIMAL(18,2);
SELECT @food_d1_net = net_customer_revenue FROM core.vw_executive_daily_revenue WHERE service_type = 'food' AND metric_date = @d1;
SELECT @food_d2_net = net_customer_revenue, @food_d2_prev = prev_day_net_revenue, @food_d2_cum = cumulative_net_revenue
FROM core.vw_executive_daily_revenue WHERE service_type = 'food' AND metric_date = @d2;

DECLARE @taxi_d1_fee DECIMAL(18,2) = (SELECT estimated_platform_revenue FROM core.vw_executive_daily_revenue WHERE service_type = 'taxi' AND metric_date = @d1);

EXEC test.sp_assert_equals 'analytics', 'vw_executive_daily_revenue: Day 1 food net revenue = $35.00', 35.00, @food_d1_net;
EXEC test.sp_assert_equals 'analytics', 'vw_executive_daily_revenue: Day 2 LAG() matches Day 1 ($35.00)', 35.00, @food_d2_prev;
EXEC test.sp_assert_equals 'analytics', 'vw_executive_daily_revenue: Day 2 running cumulative sum = $55.00', 55.00, @food_d2_cum;
EXEC test.sp_assert_equals 'analytics', 'vw_executive_daily_revenue: Day 1 taxi platform commission = $5.00', 5.00, @taxi_d1_fee;

-- 2. Coupon Campaign ROI
DECLARE @c_food_cnt INT, @c_sub DECIMAL(18,2), @c_rev DECIMAL(18,2), @c_roi DECIMAL(10,2);
SELECT @c_food_cnt = food_redemptions, @c_sub = total_discount_subsidy, @c_rev = attributed_net_revenue, @c_roi = revenue_to_subsidy_ratio
FROM core.vw_coupon_campaign_roi WHERE code = 'BI_SAVE5';

EXEC test.sp_assert_equals 'analytics', 'vw_coupon_campaign_roi: counts 1 food redemption', 1, @c_food_cnt;
EXEC test.sp_assert_equals 'analytics', 'vw_coupon_campaign_roi: sums $5.00 subsidy', 5.00, @c_sub;
EXEC test.sp_assert_equals 'analytics', 'vw_coupon_campaign_roi: attributes $35.00 net revenue', 35.00, @c_rev;
EXEC test.sp_assert_equals 'analytics', 'vw_coupon_campaign_roi: computes 7.00x revenue-to-subsidy ratio', 7.00, @c_roi;

-- 3. Customer 360 LTV (Cross-Domain without Join Fan-Out)
DECLARE @super_ltv DECIMAL(18,2), @is_super BIT, @super_rank BIGINT, @food_ltv DECIMAL(18,2), @food_is_super BIT;
SELECT @super_ltv = lifetime_total_spend, @is_super = is_super_app_user, @super_rank = ltv_rank
FROM core.vw_customer_360_ltv WHERE username = 'bi_super_user';
SELECT @food_ltv = lifetime_total_spend, @food_is_super = is_super_app_user
FROM core.vw_customer_360_ltv WHERE username = 'bi_food_user';

EXEC test.sp_assert_equals 'analytics', 'vw_customer_360_ltv: combines taxi ($25) + food ($35) = $60.00', 60.00, @super_ltv;
EXEC test.sp_assert_equals 'analytics', 'vw_customer_360_ltv: flags cross-domain user as is_super_app_user = 1', 1, @is_super;
EXEC test.sp_assert_equals 'analytics', 'vw_customer_360_ltv: ranks highest LTV customer at #1', 1, @super_rank;
EXEC test.sp_assert_equals 'analytics', 'vw_customer_360_ltv: flags single-service user as is_super_app_user = 0', 0, @food_is_super;

-- 4. Taxi Fleet Operational KPIs
DECLARE @cancel_pct DECIMAL(5,2), @fleet_gmv DECIMAL(18,2);
SELECT @cancel_pct = cancellation_rate_pct, @fleet_gmv = total_completed_gmv
FROM taxi.vw_fleet_operational_kpis WHERE vehicle_type = 'economy' AND service_type = 'passenger';

EXEC test.sp_assert_equals 'analytics', 'vw_fleet_operational_kpis: cancellation_rate_pct = 50.00% (1 of 2)', 50.00, @cancel_pct;
EXEC test.sp_assert_equals 'analytics', 'vw_fleet_operational_kpis: total_completed_gmv = $25.00', 25.00, @fleet_gmv;

-- 5. Restaurant Branch Performance & SLA Compliance
DECLARE @br_gmv DECIMAL(18,2), @br_sla DECIMAL(5,2), @br_city_rank BIGINT;
SELECT @br_gmv = delivered_gmv, @br_sla = sla_on_time_cooking_pct, @br_city_rank = city_gmv_rank
FROM food.vw_branch_performance_leaderboard WHERE brand_name = 'Analytics Grill';

EXEC test.sp_assert_equals 'analytics', 'vw_branch_performance_leaderboard: delivered_gmv = $55.00', 55.00, @br_gmv;
EXEC test.sp_assert_equals 'analytics', 'vw_branch_performance_leaderboard: sla_on_time_cooking_pct = 50.00%', 50.00, @br_sla;
EXEC test.sp_assert_equals 'analytics', 'vw_branch_performance_leaderboard: city_gmv_rank = 1', 1, @br_city_rank;

-- 6. Top-Selling Menu Items
DECLARE @units INT, @item_rev DECIMAL(18,2), @cat_rank BIGINT;
SELECT @units = total_units_sold, @item_rev = total_item_revenue, @cat_rank = category_revenue_rank
FROM food.vw_top_selling_menu_items WHERE food_name = 'Royal Kabab';

EXEC test.sp_assert_equals 'analytics', 'vw_top_selling_menu_items: total_units_sold = 3', 3, @units;
EXEC test.sp_assert_equals 'analytics', 'vw_top_selling_menu_items: total_item_revenue = $60.00', 60.00, @item_rev;
EXEC test.sp_assert_equals 'analytics', 'vw_top_selling_menu_items: category_revenue_rank = 1', 1, @cat_rank;

-- 7. Security & Index Verification
DECLARE @bi_grant_cnt INT = (
    SELECT COUNT(*)
    FROM sys.database_permissions dp
    JOIN sys.database_principals pr ON pr.principal_id = dp.grantee_principal_id
    JOIN sys.objects o ON o.object_id = dp.major_id
    WHERE pr.name = 'readonly_analyst'
      AND dp.permission_name = 'SELECT'
      AND dp.state_desc = 'GRANT'
      AND o.name IN (
          'vw_executive_daily_revenue',
          'vw_coupon_campaign_roi',
          'vw_customer_360_ltv',
          'vw_fleet_operational_kpis',
          'vw_branch_performance_leaderboard',
          'vw_top_selling_menu_items'
      )
);
EXEC test.sp_assert_equals 'analytics', 'readonly_analyst has SELECT granted on all 6 BI views', 6, @bi_grant_cnt;

DECLARE @ix_cnt INT = (
    SELECT COUNT(*)
    FROM sys.indexes
    WHERE name LIKE 'ix[_]%'
      AND is_hypothetical = 0
);
EXEC test.sp_assert_range 'analytics', 'schema/06_indexes.sql deployed all 23 performance indexes', @ix_cnt, 23, 30;
GO

EXEC test.sp_print_summary @test_suite = 'analytics';
EXEC test.sp_print_summary;
EXEC test.sp_reset_all_data;
GO
