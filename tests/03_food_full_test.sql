USE mini_snapp;
GO
SET NOCOUNT ON;
GO

-- =============================================
-- AUTOMATED TEST SUITE 03: FOOD SCHEMA & CROSS-DOMAIN DISPATCH
-- Prerequisite: tests/00_test_framework.sql
-- =============================================

EXEC test.sp_reset_all_data;
DELETE FROM test.test_results WHERE test_suite = 'food';
GO

-- PHASE 1: SEED ISOLATED FOOD & COURIER FIXTURES (USD)

INSERT INTO core.roles (role_name, role_description, hierarchy_level) VALUES
('customer',         'Customer',     1),
('driver',           'Driver',       2),
('restaurant_staff', 'Staff',        2),
('branch_owner',     'Branch Owner', 3),
('brand_owner',      'Brand Owner',  3),
('admin',            'Admin',        5);

DECLARE @r_cust  INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @r_driv  INT = (SELECT role_id FROM core.roles WHERE role_name = 'driver');
DECLARE @r_staff INT = (SELECT role_id FROM core.roles WHERE role_name = 'restaurant_staff');
DECLARE @r_bown  INT = (SELECT role_id FROM core.roles WHERE role_name = 'branch_owner');
DECLARE @r_brown INT = (SELECT role_id FROM core.roles WHERE role_name = 'brand_owner');
DECLARE @r_admin INT = (SELECT role_id FROM core.roles WHERE role_name = 'admin');

INSERT INTO core.app_wallets (total_balance) VALUES (0.00);

INSERT INTO core.commission_rates (service_type, driver_share, restaurant_share, app_share, effective_from) VALUES
('food', 15.00, 75.00, 10.00, DATEADD(MONTH, -1, GETDATE())),
('taxi', 80.00, NULL,  20.00, DATEADD(MONTH, -1, GETDATE()));

INSERT INTO taxi.vehicle_type_services (vehicle_type, service_type) VALUES
('motorcycle', 'cargo');

INSERT INTO taxi.pricing_parameters (vehicle_type, service_type, base_fare, price_per_km, price_per_minute) VALUES
('motorcycle', 'cargo', 5.00, 1.50, 0.20);

INSERT INTO core.users (username, password_hash, registration_phone, role_id) VALUES
('cust_sara',     'hash', '09120000001', @r_cust),
('cust_reza',     'hash', '09120000002', @r_cust),
('owner_leila',   'hash', '09120000003', @r_bown),
('brand_kianoosh','hash', '09120000004', @r_brown),
('staff_candidate','hash','09120000005', @r_staff),
('courier_ali',   'hash', '09120000006', @r_driv),
('admin_food',    'hash', '09120000007', @r_admin);

INSERT INTO core.user_wallets (user_id, balance)
SELECT user_id,
    CASE username
        WHEN 'cust_sara' THEN 200.00
        WHEN 'cust_reza' THEN 100.00
        ELSE 0.00
    END
FROM core.users;

DECLARE @u_sara  INT = (SELECT user_id FROM core.users WHERE username = 'cust_sara');
DECLARE @u_reza  INT = (SELECT user_id FROM core.users WHERE username = 'cust_reza');
DECLARE @u_leila INT = (SELECT user_id FROM core.users WHERE username = 'owner_leila');
DECLARE @u_kian  INT = (SELECT user_id FROM core.users WHERE username = 'brand_kianoosh');
DECLARE @u_cour  INT = (SELECT user_id FROM core.users WHERE username = 'courier_ali');

INSERT INTO core.addresses (user_id, address_name, province, city, street, latitude, longitude) VALUES
(@u_sara, 'Home', 'Tehran', 'Tehran', 'Yousefabad St', 35.72200000, 51.40800000),
(@u_reza, 'Home', 'Tehran', 'Tehran', 'Fatemi St',     35.71600000, 51.40400000);

INSERT INTO taxi.drivers (user_id, national_id, date_of_birth, driver_status, gender)
VALUES (@u_cour, '0099887766', '1996-04-12', 'available', 'male');
DECLARE @cour_driver_id INT = SCOPE_IDENTITY();
INSERT INTO taxi.driver_wallets (driver_id, balance) VALUES (@cour_driver_id, 0.00);
INSERT INTO taxi.vehicles (owner_id, vehicle_type, license_plate, color, model_name, is_active_now)
VALUES (@cour_driver_id, 'motorcycle', '44-M-999', 'Red', 'Honda 125', 1);
INSERT INTO taxi.driver_locations (driver_id, latitude, longitude, updated_at)
VALUES (@cour_driver_id, 35.71800000, 51.40900000, GETDATE());

INSERT INTO food.brands (name, central_support_phone, commission_rate, email) VALUES
('Zeytoon Grill',   '02188001122', 0.1500, 'info@zeytoon.local'),
('Baradaran Pizza', '02188003344', 0.2000, 'info@baradaran.local');

DECLARE @brand1 INT = (SELECT brand_id FROM food.brands WHERE name = 'Zeytoon Grill');
DECLARE @brand2 INT = (SELECT brand_id FROM food.brands WHERE name = 'Baradaran Pizza');
INSERT INTO food.brand_owners (user_id, brand_id) VALUES (@u_kian, @brand1);

INSERT INTO food.branches (brand_id, province, city, street, latitude, longitude, food_type, max_delivery_distance, is_active) VALUES
(@brand1, 'Tehran', 'Tehran', 'Valiasr St',  35.71850000, 51.40950000, 'Kabab', 8.00, 1),
(@brand2, 'Tehran', 'Tehran', 'Enghelab St', 35.70050000, 51.38800000, 'Pizza', 8.00, 1),
(@brand1, 'Qazvin', 'Qazvin', 'Main Blvd',   36.28950000, 50.00400000, 'Kabab', 6.00, 0);

DECLARE @branch1 INT = (SELECT branch_id FROM food.branches WHERE brand_id = @brand1 AND city = 'Tehran');
DECLARE @branch2 INT = (SELECT branch_id FROM food.branches WHERE brand_id = @brand2 AND city = 'Tehran');

INSERT INTO food.branch_owners (user_id, branch_id) VALUES (@u_leila, @branch1);

INSERT INTO food.work_schedules (branch_id, day_of_week, start_time, end_time, is_closed)
SELECT b.branch_id, d.day_of_week, '09:00', '23:00', CASE WHEN d.day_of_week = 5 THEN 1 ELSE 0 END
FROM food.branches b
CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6)) AS d(day_of_week);

INSERT INTO food.foods (brand_id, name, category) VALUES
(@brand1, 'Special Kabab',    'Kabab'),
(@brand1, 'Chicken Skewer',   'Kabab'),
(@brand2, 'Margherita Pizza', 'Pizza');

DECLARE @f_kabab   INT = (SELECT food_id FROM food.foods WHERE name = 'Special Kabab');
DECLARE @f_chicken INT = (SELECT food_id FROM food.foods WHERE name = 'Chicken Skewer');
DECLARE @f_pizza   INT = (SELECT food_id FROM food.foods WHERE name = 'Margherita Pizza');

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, estimated_prep_time) VALUES
(@branch1, @f_kabab,   20.00, 1, 25),
(@branch1, @f_chicken, 15.00, 0, 20),
(@branch2, @f_pizza,   12.00, 1, 18);

DECLARE @mi_kabab INT = (SELECT menu_item_id FROM food.menu_items WHERE branch_id = @branch1 AND food_id = @f_kabab);
INSERT INTO food.menu_discounts (menu_item_id, percentage, amount, start_at, end_at, is_active)
VALUES (@mi_kabab, 10.00, NULL, DATEADD(DAY, -1, GETDATE()), DATEADD(DAY, 5, GETDATE()), 1);
GO

-- PHASE 2: EXECUTE FOOD TESTS

PRINT '=============================================';
PRINT 'STARTING TEST SUITE: food';
PRINT '=============================================';
GO

-- Test 1: Functions & Auto-Wallet Trigger
PRINT '--- Testing Food Functions & Branch Triggers ---';

DECLARE @branch1 INT = (SELECT TOP 1 branch_id FROM food.branches WHERE city = 'Tehran' AND food_type = 'Kabab');
DECLARE @mi_kabab INT = (SELECT TOP 1 menu_item_id FROM food.menu_items WHERE branch_id = @branch1 AND availability_status = 1);

DECLARE @wallet_exists BIT = CASE WHEN EXISTS (SELECT 1 FROM food.branch_wallets WHERE branch_id = @branch1 AND balance = 0.00) THEN 1 ELSE 0 END;
EXEC test.sp_assert_true 'food', 'trg_branches_after_insert_create_wallet: auto-creates 0.00 branch wallet', @wallet_exists;

DECLARE @dist_zero DECIMAL(9,3) = food.fn_haversine_km(35.71850000, 51.40950000, 35.71850000, 51.40950000);
EXEC test.sp_assert_equals 'food', 'fn_haversine_km: identical points return 0.000', 0.000, @dist_zero;

DECLARE @in_range_cnt INT = (SELECT COUNT(*) FROM food.fn_branches_within_distance(35.71500000, 51.40000000, 10.00));
EXEC test.sp_assert_equals 'food', 'fn_branches_within_distance: returns 2 active Tehran branches (excludes inactive)', 2, @in_range_cnt;

DECLARE @open_wed BIT = food.fn_is_branch_open(@branch1, '2026-07-08 14:00:00');
DECLARE @open_fri BIT = food.fn_is_branch_open(@branch1, '2026-07-10 14:00:00');
EXEC test.sp_assert_equals 'food', 'fn_is_branch_open: open on Wednesday afternoon', 1, @open_wed;
EXEC test.sp_assert_equals 'food', 'fn_is_branch_open: closed on Friday', 0, @open_fri;

DECLARE @eff_price DECIMAL(10,2) = food.fn_get_effective_menu_price(@mi_kabab);
EXEC test.sp_assert_equals 'food', 'fn_get_effective_menu_price: applies 10% active discount ($20.00 -> $18.00)', 18.00, @eff_price;
GO

-- Test 2: Discount Validation, Staff Rules & Cart Procedures
PRINT '--- Testing Cart, Staff & Discount Constraints ---';

DECLARE @branch1 INT = (SELECT TOP 1 branch_id FROM food.branches WHERE city = 'Tehran' AND food_type = 'Kabab');
DECLARE @branch2 INT = (SELECT TOP 1 branch_id FROM food.branches WHERE city = 'Tehran' AND food_type = 'Pizza');
DECLARE @mi_kabab   INT = (SELECT menu_item_id FROM food.menu_items WHERE branch_id = @branch1 AND availability_status = 1);
DECLARE @mi_unavail INT = (SELECT menu_item_id FROM food.menu_items WHERE branch_id = @branch1 AND availability_status = 0);
DECLARE @mi_pizza   INT = (SELECT menu_item_id FROM food.menu_items WHERE branch_id = @branch2 AND availability_status = 1);
DECLARE @u_sara     INT = (SELECT user_id FROM core.users WHERE username = 'cust_sara');
DECLARE @u_leila    INT = (SELECT user_id FROM core.users WHERE username = 'owner_leila');
DECLARE @u_staff    INT = (SELECT user_id FROM core.users WHERE username = 'staff_candidate');

DECLARE @overlap_blocked BIT = 0;
DECLARE @ov_start DATETIME2 = SYSDATETIME();
DECLARE @ov_end   DATETIME2 = DATEADD(DAY, 3, SYSDATETIME());
BEGIN TRY
    EXEC food.sp_create_menu_discount @mi_kabab, 15.00, NULL, @ov_start, @ov_end;
END TRY
BEGIN CATCH
    SET @overlap_blocked = 1;
END CATCH
EXEC test.sp_assert_true 'food', 'trg_menu_discounts_validate: blocks overlapping active discount period', @overlap_blocked;

EXEC food.sp_assign_restaurant_staff @u_staff, @branch1;
DECLARE @staff_assigned BIT = CASE WHEN EXISTS (SELECT 1 FROM food.restaurant_staff WHERE user_id = @u_staff AND branch_id = @branch1) THEN 1 ELSE 0 END;
EXEC test.sp_assert_true 'food', 'sp_assign_restaurant_staff: assigns eligible user to branch', @staff_assigned;

DECLARE @owner_staff_blocked BIT = 0;
BEGIN TRY
    EXEC food.sp_assign_restaurant_staff @u_leila, @branch1;
END TRY
BEGIN CATCH
    SET @owner_staff_blocked = 1;
END CATCH
EXEC test.sp_assert_true 'food', 'sp_assign_restaurant_staff: blocks assigning branch owner as staff', @owner_staff_blocked;

EXEC food.sp_add_to_cart @u_sara, @branch1, @mi_kabab, 2;
DECLARE @cart_total DECIMAL(10,2) = food.fn_calculate_cart_total(@u_sara, @branch1);
EXEC test.sp_assert_equals 'food', 'sp_add_to_cart & fn_calculate_cart_total: 2 * $18.00 = $36.00', 36.00, @cart_total;

DECLARE @unavail_blocked BIT = 0;
BEGIN TRY
    EXEC food.sp_add_to_cart @u_sara, @branch1, @mi_unavail, 1;
END TRY
BEGIN CATCH
    SET @unavail_blocked = 1;
END CATCH
EXEC test.sp_assert_true 'food', 'sp_add_to_cart: rejects unavailable menu item', @unavail_blocked;

DECLARE @cross_branch_blocked BIT = 0;
BEGIN TRY
    EXEC food.sp_add_to_cart @u_sara, @branch2, @mi_pizza, 1;
END TRY
BEGIN CATCH
    SET @cross_branch_blocked = 1;
END CATCH
EXEC test.sp_assert_true 'food', 'sp_add_to_cart: enforces single-branch cart rule', @cross_branch_blocked;
GO

-- Test 3: Delivery Order Purchase, Commission Split & Automatic Courier Dispatch
PRINT '--- Testing Order Purchase, Escrow & Cross-Domain Courier Dispatch ---';

DECLARE @u_sara   INT = (SELECT user_id FROM core.users WHERE username = 'cust_sara');
DECLARE @branch1  INT = (SELECT TOP 1 branch_id FROM food.branches WHERE city = 'Tehran' AND food_type = 'Kabab');
DECLARE @mi_kabab INT = (SELECT menu_item_id FROM food.menu_items WHERE branch_id = @branch1 AND availability_status = 1);
DECLARE @addr_id  INT = (SELECT address_id FROM core.addresses WHERE user_id = @u_sara AND address_name = 'Home');

INSERT INTO food.food_orders (customer_id, branch_id, delivery_address_id, delivery_fee, final_price, allocated_discount, is_takeout, status)
VALUES (@u_sara, @branch1, @addr_id, 4.00, 0.00, 0.00, 0, 'pending');
DECLARE @ord1 INT = SCOPE_IDENTITY();

INSERT INTO food.order_items (order_id, menu_item_id, quantity, current_price)
VALUES (@ord1, @mi_kabab, 2, food.fn_get_effective_menu_price(@mi_kabab));

-- Expected: 2 * $18.00 = $36.00 food + $4.00 delivery = $40.00 total
-- Zeytoon Grill commission = 15% -> Restaurant gets $36.00 * 0.85 = $30.60, App gets $36.00 * 0.15 = $5.40
DECLARE @ord_final DECIMAL(10,2) = (SELECT final_price FROM food.food_orders WHERE order_id = @ord1);
DECLARE @sara_bal  DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @u_sara);
DECLARE @br_bal    DECIMAL(10,2) = (SELECT balance FROM food.branch_wallets WHERE branch_id = @branch1);
DECLARE @app_bal   DECIMAL(10,2) = (SELECT TOP 1 total_balance FROM core.app_wallets);
DECLARE @cart_left INT = (SELECT COUNT(*) FROM food.cart_items WHERE user_id = @u_sara);
DECLARE @courier_offers INT = (SELECT COUNT(*) FROM taxi.ride_offers WHERE passenger_id = @u_sara AND vehicle_type = 'motorcycle' AND service_type = 'cargo');
DECLARE @courier_cands  INT = (SELECT COUNT(*) FROM taxi.ride_offer_candidates);

EXEC test.sp_assert_equals 'food', 'trg_order_purchase: calculates final_price ($36.00 + $4.00 = $40.00)', 40.00, @ord_final;
EXEC test.sp_assert_equals 'food', 'trg_order_purchase: deducts $40.00 from customer wallet ($200 -> $160)', 160.00, @sara_bal;
EXEC test.sp_assert_equals 'food', 'trg_order_purchase: credits 85% food share ($30.60) to branch_wallet', 30.60, @br_bal;
EXEC test.sp_assert_equals 'food', 'trg_order_purchase: credits 15% commission ($5.40) to app_wallet', 5.40, @app_bal;
EXEC test.sp_assert_equals 'food', 'trg_order_purchase: clears customer cart after purchase', 0, @cart_left;
EXEC test.sp_assert_equals 'food', 'trg_order_purchase: dispatches motorcycle cargo ride_offer in taxi schema', 1, @courier_offers;
EXEC test.sp_assert_equals 'food', 'trg_order_purchase: matches nearby available motorcycle courier', 1, @courier_cands;
GO

-- Test 4: Order State Machine, Timestamp Autofill, Cancellation & Refund
PRINT '--- Testing Order Lifecycle, Timestamps & Cancellation Refund ---';

DECLARE @ord1 INT = (SELECT TOP 1 order_id FROM food.food_orders ORDER BY order_id ASC);
DECLARE @u_admin INT = (SELECT user_id FROM core.users WHERE username = 'admin_food');
EXEC sp_set_session_context @key = N'current_user_id', @value = @u_admin;

DECLARE @skip_stage_blocked BIT = 0;
BEGIN TRY
    UPDATE food.food_orders SET status = 'picked_up' WHERE order_id = @ord1;
END TRY
BEGIN CATCH
    SET @skip_stage_blocked = 1;
END CATCH
EXEC test.sp_assert_true 'food', 'trg_food_orders_status_validate: blocks stage skipping (pending -> picked_up)', @skip_stage_blocked;

UPDATE food.food_orders SET status = 'confirmed' WHERE order_id = @ord1;
UPDATE food.food_orders SET status = 'preparing' WHERE order_id = @ord1;
UPDATE food.food_orders SET status = 'picked_up' WHERE order_id = @ord1;
UPDATE food.food_orders SET status = 'delivered' WHERE order_id = @ord1;

DECLARE @delivered_ts DATETIME2 = (SELECT delivered_at FROM food.food_orders WHERE order_id = @ord1);
EXEC test.sp_assert_not_null 'food', 'trg_food_orders_timestamp_autofill: populates delivered_at automatically', @delivered_ts;

DECLARE @cancel_delivered_blocked BIT = 0;
BEGIN TRY
    EXEC food.sp_cancel_order @ord1, 'restaurant', 'Too late';
END TRY
BEGIN CATCH
    SET @cancel_delivered_blocked = 1;
END CATCH
EXEC test.sp_assert_true 'food', 'sp_cancel_order: blocks cancelling an already delivered order', @cancel_delivered_blocked;

-- Create a second takeout order for Reza, then cancel while pending and verify full refund
DECLARE @u_reza   INT = (SELECT user_id FROM core.users WHERE username = 'cust_reza');
DECLARE @branch2  INT = (SELECT TOP 1 branch_id FROM food.branches WHERE city = 'Tehran' AND food_type = 'Pizza');
DECLARE @mi_pizza INT = (SELECT menu_item_id FROM food.menu_items WHERE branch_id = @branch2 AND availability_status = 1);

INSERT INTO food.food_orders (customer_id, branch_id, delivery_fee, final_price, allocated_discount, is_takeout, status)
VALUES (@u_reza, @branch2, 0.00, 0.00, 0.00, 1, 'pending');
DECLARE @ord2 INT = SCOPE_IDENTITY();

INSERT INTO food.order_items (order_id, menu_item_id, quantity, current_price)
VALUES (@ord2, @mi_pizza, 2, food.fn_get_effective_menu_price(@mi_pizza));

DECLARE @reza_after_buy DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @u_reza);
EXEC test.sp_assert_equals 'food', 'Takeout order deducts 2 * $12.00 = $24.00 ($100 -> $76)', 76.00, @reza_after_buy;

EXEC food.sp_cancel_order @ord2, 'user', 'Ordered by mistake';
DECLARE @reza_after_cancel DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @u_reza);
DECLARE @ord2_status VARCHAR(20) = (SELECT status FROM food.food_orders WHERE order_id = @ord2);
EXEC test.sp_assert_equals 'food', 'sp_cancel_order: refunds full $24.00 back to customer wallet', 100.00, @reza_after_cancel;
EXEC test.sp_assert_equals 'food', 'sp_cancel_order: updates order status to cancelled', 'cancelled', @ord2_status;

DECLARE @audit_cnt INT = (
    SELECT COUNT(*) FROM food.food_logs
    WHERE target_table = 'food_orders' AND target_id = CAST(@ord1 AS VARCHAR(50)) AND operation_type = 'update'
);
EXEC test.sp_assert_equals 'food', 'trg_food_orders_audit: records all 4 status transitions in food_logs', 4, @audit_cnt;

EXEC sp_set_session_context @key = N'current_user_id', @value = NULL;
GO

EXEC test.sp_print_summary @test_suite = 'food';
EXEC test.sp_print_summary; -- Grand summary across all suites run in session
EXEC test.sp_reset_all_data;
GO
