USE mini_snapp;
GO
SET NOCOUNT ON;
GO

-- =============================================
-- AUTOMATED TEST SUITE 01: CORE SCHEMA
-- Prerequisite: tests/00_test_framework.sql
-- =============================================

EXEC test.sp_reset_all_data;
DELETE FROM test.test_results WHERE test_suite = 'core';
GO

-- PHASE 1: SEED ISOLATED CORE TEST FIXTURES (USD)

INSERT INTO core.roles (role_name, role_description, hierarchy_level) VALUES
('customer',         'Regular user',  1),
('driver',           'Taxi driver',   2),
('restaurant_staff', 'Staff',         2),
('branch_owner',     'Branch Owner',  3),
('brand_owner',      'Brand Owner',   3),
('admin',            'Admin',         5),
('super_admin',      'Super Admin',  10);

INSERT INTO core.permissions (permission_name, permission_description) VALUES
('can_ban_user',          'Block user'),
('can_create_coupon',     'Create coupon'),
('can_edit_coupon',       'Edit coupon'),
('can_resolve_complaint', 'Resolve complaint'),
('can_view_financials',   'View financials'),
('can_manage_admins',     'Manage admins'),
('can_manage_branches',   'Manage branches'),
('can_manage_drivers',    'Manage drivers'),
('can_issue_refund',      'Issue refund'),
('can_view_logs',         'View logs');

INSERT INTO core.role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM core.roles r
CROSS JOIN core.permissions p
WHERE r.role_name = 'super_admin';

INSERT INTO core.role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM core.roles r
JOIN core.permissions p ON p.permission_name IN (
    'can_ban_user', 'can_create_coupon', 'can_edit_coupon', 'can_resolve_complaint',
    'can_view_financials', 'can_manage_branches', 'can_manage_drivers', 'can_issue_refund', 'can_view_logs'
)
WHERE r.role_name = 'admin';

INSERT INTO core.coupons (code, [percentage], amount, min_requirement, max_cap, [expiry_date], current_usage, max_usage, is_active) VALUES
('WELCOME20', 20.00, NULL,  15.00, 10.00, DATEADD(MONTH, 2, GETDATE()), 3, 100, 1),
('FLAT5',     NULL,  5.00,  20.00, NULL,  DATEADD(MONTH, 1, GETDATE()), 0,  50, 1),
('EXPIRED10', 10.00, NULL,  10.00,  5.00, DATEADD(DAY,  -5, GETDATE()), 2,  20, 1),
('MAXEDOUT',  15.00, NULL,   0.00, NULL,  DATEADD(MONTH, 3, GETDATE()), 10, 10, 1),
('DISABLED5',  5.00, NULL,   0.00, NULL,  DATEADD(MONTH, 1, GETDATE()), 0, 100, 0),
('HIGHMIN',   30.00, NULL, 200.00, 50.00, DATEADD(MONTH, 1, GETDATE()), 0,  30, 1),
('SMALLCAP',  50.00, NULL,  10.00,  4.00, DATEADD(MONTH, 1, GETDATE()), 4,  40, 1),
('LASTUSE',   NULL,  6.00,   0.00, NULL,  DATEADD(MONTH, 1, GETDATE()), 9,  10, 1);

INSERT INTO core.app_wallets (total_balance) VALUES (0.00);

INSERT INTO core.commission_rates (service_type, driver_share, restaurant_share, app_share, effective_from, effective_to) VALUES
('food', 15.00, 75.00, 10.00, DATEADD(MONTH, -1, GETDATE()), NULL),
('taxi', 80.00, NULL,  20.00, DATEADD(MONTH, -1, GETDATE()), NULL),
('food', 16.00, 74.00, 10.00, DATEADD(MONTH, -3, GETDATE()), DATEADD(MONTH, -1, GETDATE()));

DECLARE @role_customer INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @role_driver   INT = (SELECT role_id FROM core.roles WHERE role_name = 'driver');
DECLARE @role_staff    INT = (SELECT role_id FROM core.roles WHERE role_name = 'restaurant_staff');
DECLARE @role_admin    INT = (SELECT role_id FROM core.roles WHERE role_name = 'admin');

INSERT INTO core.users (username, password_hash, first_name, last_name, registration_phone, email, role_id, is_blocked, deleted_at) VALUES
('sara_ahmadi',    '$2b$12$hash', 'Sara',    'Ahmadi',  '09121234501', 'sara@test.com',   @role_customer, 0, NULL),
('reza_karimi',    '$2b$12$hash', 'Reza',    'Karimi',  '09121234502', 'reza@test.com',   @role_customer, 0, NULL),
('mina_hosseini',  '$2b$12$hash', 'Mina',    'Hosseini','09121234503', 'mina@test.com',   @role_customer, 1, NULL),
('old_account99',  '$2b$12$hash', 'Farhad',  'Ghasemi', '09121234504', 'old@test.com',    @role_customer, 0, DATEADD(MONTH, -2, GETDATE())),
('behnam_moshiri', '$2b$12$hash', 'Behnam',  'Moshiri', '09121234505', 'behnam@test.com', @role_customer, 0, NULL),
('driver_neda',    '$2b$12$hash', 'Neda',    'Rostami', '09121234507', 'neda@test.com',   @role_driver,   0, NULL),
('staff_hamed',    '$2b$12$hash', 'Hamed',   'Jafari',  '09121234509', 'hamed@test.com',  @role_staff,    0, NULL),
('admin_yasaman',  '$2b$12$hash', 'Yasaman', 'Bahrami', '09121234512', 'admin@test.com',  @role_admin,    0, NULL);

INSERT INTO core.user_wallets (user_id, balance)
SELECT user_id,
    CASE username
        WHEN 'sara_ahmadi' THEN 250.00
        WHEN 'reza_karimi' THEN   0.00
        ELSE 50.00
    END
FROM core.users;

INSERT INTO core.admins (user_id, admin_identifier, access_level)
SELECT user_id, 'ADM-1001', 'full' FROM core.users WHERE username = 'admin_yasaman';
GO

-- PHASE 2: EXECUTE CORE TESTS

PRINT '=============================================';
PRINT 'STARTING TEST SUITE: core';
PRINT '=============================================';
GO

-- Test 1: Functions
PRINT '--- Testing Core Functions ---';

DECLARE @dist_same_point DECIMAL(10,2) = core.fn_calculate_distance_km(35.6892, 51.3890, 35.6892, 51.3890);
EXEC test.sp_assert_equals 'core', 'fn_calculate_distance_km: identical coordinates return 0.00', 0.00, @dist_same_point;

DECLARE @dist_tehran_isfahan DECIMAL(10,2) = core.fn_calculate_distance_km(35.6892, 51.3890, 32.6546, 51.6679);
EXEC test.sp_assert_range 'core', 'fn_calculate_distance_km: Tehran to Isfahan is ~340 km', @dist_tehran_isfahan, 320.00, 360.00;

DECLARE @admin_user_id INT = (SELECT user_id FROM core.users WHERE username = 'admin_yasaman');
DECLARE @customer_user_id INT = (SELECT user_id FROM core.users WHERE username = 'sara_ahmadi');

DECLARE @has_admin_lvl BIT = core.fn_has_minimum_role_level(@admin_user_id, 5);
EXEC test.sp_assert_equals 'core', 'fn_has_minimum_role_level: admin meets level 5', 1, @has_admin_lvl;

DECLARE @cust_has_admin_lvl BIT = core.fn_has_minimum_role_level(@customer_user_id, 5);
EXEC test.sp_assert_equals 'core', 'fn_has_minimum_role_level: customer does not meet level 5', 0, @cust_has_admin_lvl;

DECLARE @reza_id INT = (SELECT user_id FROM core.users WHERE username = 'reza_karimi');
DECLARE @val_flat5 BIT = core.fn_validate_coupon('FLAT5', @reza_id, 30.00);
EXEC test.sp_assert_equals 'core', 'fn_validate_coupon: FLAT5 valid for eligible order amount', 1, @val_flat5;

DECLARE @val_expired BIT = core.fn_validate_coupon('EXPIRED10', @reza_id, 30.00);
EXEC test.sp_assert_equals 'core', 'fn_validate_coupon: expired coupon rejected', 0, @val_expired;

DECLARE @past_food_driver_share DECIMAL(5,2) = (
    SELECT driver_share FROM core.fn_get_active_commission_rate('food', DATEADD(MONTH, -2, GETDATE()))
);
EXEC test.sp_assert_equals 'core', 'fn_get_active_commission_rate: temporal lookup returns historical rate', 16.00, @past_food_driver_share;
GO

-- Test 2: Write Procedures & Triggers
PRINT '--- Testing Core Write Procedures & Triggers ---';

DECLARE @role_customer_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @test_new_user_id INT;

EXEC core.sp_register_user
    @username = 'newbie_taha',
    @password_hash = 'hash',
    @registration_phone = '09121234513',
    @role_id = @role_customer_id,
    @new_user_id = @test_new_user_id OUTPUT;

EXEC test.sp_assert_not_null 'core', 'sp_register_user: returns new_user_id', @test_new_user_id;

DECLARE @actual_wallet_balance DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @test_new_user_id);
EXEC test.sp_assert_equals 'core', 'sp_register_user: auto-creates wallet with 0.00 balance', 0.00, @actual_wallet_balance;

EXEC core.sp_charge_wallet @user_id = @test_new_user_id, @amount = 75.00, @payment_method = 'card';
SET @actual_wallet_balance = (SELECT balance FROM core.user_wallets WHERE user_id = @test_new_user_id);
EXEC test.sp_assert_equals 'core', 'sp_charge_wallet: increments wallet balance accurately', 75.00, @actual_wallet_balance;

DECLARE @neg_charge_blocked BIT = 0;
BEGIN TRY
    EXEC core.sp_charge_wallet @user_id = @test_new_user_id, @amount = -10.00, @payment_method = 'card';
END TRY
BEGIN CATCH
    SET @neg_charge_blocked = 1;
END CATCH
EXEC test.sp_assert_true 'core', 'sp_charge_wallet: blocks negative amount', @neg_charge_blocked;

DECLARE @promote_user_id INT = (SELECT user_id FROM core.users WHERE username = 'driver_neda');
DECLARE @admin_role_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'admin');
EXEC core.sp_assign_admin_role @user_id = @promote_user_id, @admin_identifier = 'ADM-TEST-01', @access_level = 'limited';

DECLARE @actual_role_id INT = (SELECT role_id FROM core.users WHERE user_id = @promote_user_id);
EXEC test.sp_assert_equals 'core', 'sp_assign_admin_role: syncs user role_id to admin', @admin_role_id, @actual_role_id;

-- Test coupon discount application & auto-deactivation trigger on a real order
INSERT INTO food.brands (name, commission_rate) VALUES ('Coupon Test Brand', 0.1500);
DECLARE @cb_id INT = SCOPE_IDENTITY();
INSERT INTO food.branches (brand_id, province, city, street, latitude, longitude, food_type, max_delivery_distance)
VALUES (@cb_id, 'Tehran', 'Tehran', 'Test St', 35.70000000, 51.40000000, 'Fast Food', 5.00);
DECLARE @cbr_id INT = SCOPE_IDENTITY();

INSERT INTO food.food_orders (customer_id, branch_id, delivery_fee, final_price, allocated_discount, is_takeout, status)
VALUES (@test_new_user_id, @cbr_id, 0.00, 20.00, 0.00, 1, 'pending');
DECLARE @c_ord1 INT = SCOPE_IDENTITY();

EXEC core.sp_apply_coupon @coupon_code = 'SMALLCAP', @user_id = @test_new_user_id, @order_amount = 20.00, @order_id = @c_ord1;
DECLARE @applied_disc DECIMAL(10,2) = (SELECT allocated_discount FROM food.food_orders WHERE order_id = @c_ord1);
DECLARE @updated_final DECIMAL(10,2) = (SELECT final_price FROM food.food_orders WHERE order_id = @c_ord1);
EXEC test.sp_assert_equals 'core', 'sp_apply_coupon: enforces max_cap ($4.00 on 50% of $20.00)', 4.00, @applied_disc;
EXEC test.sp_assert_equals 'core', 'sp_apply_coupon: deducts discount from order final_price', 16.00, @updated_final;

INSERT INTO food.food_orders (customer_id, branch_id, delivery_fee, final_price, allocated_discount, is_takeout, status)
VALUES (@test_new_user_id, @cbr_id, 0.00, 15.00, 0.00, 1, 'pending');
DECLARE @c_ord2 INT = SCOPE_IDENTITY();

EXEC core.sp_apply_coupon @coupon_code = 'LASTUSE', @user_id = @test_new_user_id, @order_amount = 15.00, @order_id = @c_ord2;
DECLARE @lastuse_active BIT = (SELECT is_active FROM core.coupons WHERE code = 'LASTUSE');
EXEC test.sp_assert_equals 'core', 'trg_coupons_after_update: auto-deactivates coupon when max_usage reached', 0, @lastuse_active;
GO

-- Test 3: Read APIs
PRINT '--- Testing Core Read APIs ---';

DECLARE @CheckUserResult TABLE (username_exists BIT, phone_exists BIT, email_exists BIT);
INSERT INTO @CheckUserResult
EXEC core.sp_check_user_exists @username = 'sara_ahmadi', @registration_phone = '09121234501', @email = 'sara@test.com';

DECLARE @ue BIT, @pe BIT, @ee BIT;
SELECT TOP 1 @ue = username_exists, @pe = phone_exists, @ee = email_exists FROM @CheckUserResult;
EXEC test.sp_assert_equals 'core', 'sp_check_user_exists: detects existing username', 1, @ue;
EXEC test.sp_assert_equals 'core', 'sp_check_user_exists: detects existing phone', 1, @pe;
EXEC test.sp_assert_equals 'core', 'sp_check_user_exists: detects existing email', 1, @ee;
GO

DECLARE @ProfileResult TABLE (
    user_id INT, username VARCHAR(50), first_name VARCHAR(50), last_name VARCHAR(50),
    registration_phone VARCHAR(15), email VARCHAR(100), created_at DATETIME,
    role_name VARCHAR(20), hierarchy_level INT, balance DECIMAL(10,2)
);
DECLARE @sara_id INT = (SELECT user_id FROM core.users WHERE username = 'sara_ahmadi');
INSERT INTO @ProfileResult EXEC core.sp_get_user_profile @user_id = @sara_id;

DECLARE @profile_username VARCHAR(50), @profile_balance DECIMAL(10,2);
SELECT TOP 1 @profile_username = username, @profile_balance = balance FROM @ProfileResult;
EXEC test.sp_assert_equals 'core', 'sp_get_user_profile: returns expected username', 'sara_ahmadi', @profile_username;
EXEC test.sp_assert_equals 'core', 'sp_get_user_profile: returns expected USD wallet balance', 250.00, @profile_balance;
GO

DECLARE @CouponsResult TABLE (
    coupon_id INT, code VARCHAR(20), percentage DECIMAL(5,2), amount DECIMAL(10,2),
    min_requirement DECIMAL(10,2), max_cap DECIMAL(10,2), expiry_date DATETIME,
    current_usage INT, max_usage INT, remaining_uses INT
);
INSERT INTO @CouponsResult EXEC core.sp_get_available_coupons;

DECLARE @active_coupons_count INT = (SELECT COUNT(*) FROM @CouponsResult);
-- WELCOME20, FLAT5, HIGHMIN, SMALLCAP remain active (LASTUSE reached max_usage above -> 4 active)
EXEC test.sp_assert_equals 'core', 'sp_get_available_coupons: returns only active unexhausted coupons', 4, @active_coupons_count;
GO

DECLARE @LoginResult TABLE (is_success INT, [message] VARCHAR(255), user_id INT, role_id INT);
DECLARE @login_success INT;

INSERT INTO @LoginResult EXEC core.sp_verify_login 'sara_ahmadi', '$2b$12$hash';
SELECT TOP 1 @login_success = is_success FROM @LoginResult;
EXEC test.sp_assert_equals 'core', 'sp_verify_login: accepts valid credentials', 1, @login_success;
DELETE FROM @LoginResult;

INSERT INTO @LoginResult EXEC core.sp_verify_login 'sara_ahmadi', 'wrong_hash';
SELECT TOP 1 @login_success = is_success FROM @LoginResult;
EXEC test.sp_assert_equals 'core', 'sp_verify_login: rejects invalid password', 0, @login_success;
DELETE FROM @LoginResult;

INSERT INTO @LoginResult EXEC core.sp_verify_login 'mina_hosseini', '$2b$12$hash';
SELECT TOP 1 @login_success = is_success FROM @LoginResult;
EXEC test.sp_assert_equals 'core', 'sp_verify_login: blocks suspended user', 0, @login_success;
DELETE FROM @LoginResult;

INSERT INTO @LoginResult EXEC core.sp_verify_login 'old_account99', '$2b$12$hash';
SELECT TOP 1 @login_success = is_success FROM @LoginResult;
EXEC test.sp_assert_equals 'core', 'sp_verify_login: blocks soft-deleted user', 0, @login_success;
GO

EXEC test.sp_print_summary @test_suite = 'core';
EXEC test.sp_reset_all_data;
GO
