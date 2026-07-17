USE mini_snapp;
GO

-- PHASE 1: TEST FRAMEWORK SETUP

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'test')
BEGIN
    EXEC('CREATE SCHEMA test');
END
GO

IF OBJECT_ID('test.test_results', 'U') IS NOT NULL DROP TABLE test.test_results;
CREATE TABLE test.test_results (
    test_result_id INT IDENTITY(1,1) NOT NULL,
    test_suite   VARCHAR(50)  NOT NULL, 
    test_name    VARCHAR(200) NOT NULL,
    result       VARCHAR(10)  NOT NULL, 
    expected_val VARCHAR(500) ,
    actual_val   VARCHAR(500) ,
    run_at       DATETIME DEFAULT GETDATE(),
    CONSTRAINT pk_test_results PRIMARY KEY (test_result_id),
    CONSTRAINT chk_test_results_result CHECK (result IN ('PASS','FAIL'))
);
GO

CREATE OR ALTER PROCEDURE test.sp_assert_equals
    @test_suite VARCHAR(50), @test_name VARCHAR(200), @expected SQL_VARIANT, @actual SQL_VARIANT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @result VARCHAR(10);
    IF @expected = @actual OR (@expected IS NULL AND @actual IS NULL) SET @result = 'PASS';
    ELSE SET @result = 'FAIL';
    
    INSERT INTO test.test_results (test_suite, test_name, result, expected_val, actual_val)
    VALUES (@test_suite, @test_name, @result, CAST(@expected AS VARCHAR(500)), CAST(@actual AS VARCHAR(500)));
    
    IF @result = 'PASS' PRINT '  [PASS] ' + @test_name;
    ELSE PRINT '  [FAIL] ' + @test_name + ' | expected=' + CAST(@expected AS VARCHAR(500)) + ' actual=' + CAST(@actual AS VARCHAR(500));
END
GO

CREATE OR ALTER PROCEDURE test.sp_assert_range
    @test_suite VARCHAR(50), @test_name VARCHAR(200), @actual DECIMAL(18,4), @min_expected DECIMAL(18,4), @max_expected DECIMAL(18,4)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @result VARCHAR(10);
    DECLARE @expected_range VARCHAR(500) = 'between ' + CAST(@min_expected AS VARCHAR(50)) + ' and ' + CAST(@max_expected AS VARCHAR(50));
    IF @actual BETWEEN @min_expected AND @max_expected SET @result = 'PASS';
    ELSE SET @result = 'FAIL';
    
    INSERT INTO test.test_results (test_suite, test_name, result, expected_val, actual_val)
    VALUES (@test_suite, @test_name, @result, @expected_range, CAST(@actual AS VARCHAR(500)));
    
    IF @result = 'PASS' PRINT '  [PASS] ' + @test_name;
    ELSE PRINT '  [FAIL] ' + @test_name + ' | expected=' + @expected_range + ' actual=' + CAST(@actual AS VARCHAR(500));
END
GO

CREATE OR ALTER PROCEDURE test.sp_assert_true
    @test_suite VARCHAR(50), @test_name VARCHAR(200), @condition BIT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @result VARCHAR(10);
    IF @condition = 1 SET @result = 'PASS';
    ELSE SET @result = 'FAIL';
    
    INSERT INTO test.test_results (test_suite, test_name, result, expected_val, actual_val)
    VALUES (@test_suite, @test_name, @result, '1 (true)', CAST(@condition AS VARCHAR(10)));
    
    IF @result = 'PASS' PRINT '  [PASS] ' + @test_name;
    ELSE PRINT '  [FAIL] ' + @test_name + ' | expected condition to be true, was false';
END
GO

CREATE OR ALTER PROCEDURE test.sp_assert_not_null
    @test_suite VARCHAR(50), @test_name VARCHAR(200), @value SQL_VARIANT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @result VARCHAR(10);
    IF @value IS NOT NULL SET @result = 'PASS';
    ELSE SET @result = 'FAIL';
    
    INSERT INTO test.test_results (test_suite, test_name, result, expected_val, actual_val)
    VALUES (@test_suite, @test_name, @result, 'NOT NULL', CAST(@value AS VARCHAR(500)));
    
    IF @result = 'PASS' PRINT '  [PASS] ' + @test_name;
    ELSE PRINT '  [FAIL] ' + @test_name + ' | expected a non-null value, got NULL';
END
GO

CREATE OR ALTER PROCEDURE test.sp_print_summary
    @test_suite VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @total INT, @passed INT, @failed INT;
    SELECT @total = COUNT(*), @passed = SUM(CASE WHEN result = 'PASS' THEN 1 ELSE 0 END), @failed = SUM(CASE WHEN result = 'FAIL' THEN 1 ELSE 0 END)
    FROM test.test_results WHERE (@test_suite IS NULL OR test_suite = @test_suite);
    
    PRINT '=============================================';
    PRINT 'TEST SUMMARY' + ISNULL(' — ' + @test_suite, ' — ALL SUITES');
    PRINT 'Total:  ' + CAST(@total AS VARCHAR(10));
    PRINT 'Passed: ' + CAST(@passed AS VARCHAR(10));
    PRINT 'Failed: ' + CAST(@failed AS VARCHAR(10));
    PRINT '=============================================';
    IF @failed > 0
    BEGIN
        PRINT 'Failed tests:';
        SELECT test_name, expected_val, actual_val FROM test.test_results WHERE result = 'FAIL' AND (@test_suite IS NULL OR test_suite = @test_suite);
    END
END
GO


-- PHASE 2: PRE-CLEANUP (Wipe before test)

DELETE FROM taxi.ride_payments; DELETE FROM taxi.taxi_logs; DELETE FROM taxi.passenger_stats;
DELETE FROM taxi.ride_offer_candidates; DELETE FROM taxi.ride_offers; DELETE FROM taxi.rides;
DELETE FROM taxi.pricing_parameters; DELETE FROM taxi.driver_secondary_phones; 
DELETE FROM taxi.driver_locations; DELETE FROM taxi.driver_wallets; 
DELETE FROM taxi.vehicle_type_services; DELETE FROM taxi.vehicles; DELETE FROM taxi.drivers;

DELETE FROM core.core_logs; DELETE FROM core.coupon_usages; DELETE FROM core.complaints;
DELETE FROM core.transactions; DELETE FROM core.saved_accounts; DELETE FROM core.addresses;
DELETE FROM core.admins; DELETE FROM core.user_wallets; DELETE FROM core.role_permissions;
DELETE FROM core.users; DELETE FROM core.roles; DELETE FROM core.permissions;
DELETE FROM core.coupons; DELETE FROM core.app_wallets; DELETE FROM core.commission_rates;
GO


-- PHASE 3: SEED TEST DATA

INSERT INTO core.roles (role_name, role_description, hierarchy_level) VALUES
('customer', 'Regular user', 1), ('driver', 'Taxi driver', 2), ('restaurant_staff', 'Staff', 2),
('branch_owner', 'Branch Owner', 3), ('brand_owner', 'Brand Owner', 3),
('admin', 'Admin', 5), ('super_admin', 'Super Admin', 10);

INSERT INTO core.permissions (permission_name, permission_description) VALUES
('can_ban_user', 'Block user'), ('can_create_coupon', 'Create coupon'), ('can_edit_coupon', 'Edit coupon'),
('can_resolve_complaint', 'Resolve complaint'), ('can_view_financials', 'View financials'),
('can_manage_admins', 'Manage admins'), ('can_manage_branches', 'Manage branches'),
('can_manage_drivers', 'Manage drivers'), ('can_issue_refund', 'Issue refund'), ('can_view_logs', 'View logs');

INSERT INTO core.role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id FROM core.roles r JOIN core.permissions p ON 1=1 WHERE r.role_name = 'super_admin';

INSERT INTO core.role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id FROM core.roles r JOIN core.permissions p ON p.permission_name IN
('can_ban_user','can_create_coupon','can_edit_coupon','can_resolve_complaint', 'can_view_financials','can_manage_branches','can_manage_drivers','can_issue_refund','can_view_logs')
WHERE r.role_name = 'admin';

INSERT INTO core.coupons (code, percentage, amount, min_requirement, max_cap, expiry_date, current_usage, max_usage, is_active) VALUES
('WELCOME20', 20.00, NULL, 50000.00, 30000.00, DATEADD(MONTH, 2, GETDATE()), 3, 100, 1),
('FLAT50K', NULL, 50000.00, 100000.00, NULL, DATEADD(MONTH, 1, GETDATE()), 0, 50, 1),
('EXPIRED10', 10.00, NULL, 20000.00, 10000.00, DATEADD(DAY, -5, GETDATE()), 2, 20, 1),
('MAXEDOUT', 15.00, NULL, 0.00, NULL, DATEADD(MONTH, 3, GETDATE()), 10, 10, 1),
('DISABLED5', 5.00, NULL, 0.00, NULL, DATEADD(MONTH, 1, GETDATE()), 0, 100, 0),
('HIGHMIN', 30.00, NULL, 500000.00, 100000.00, DATEADD(MONTH, 1, GETDATE()), 0, 30, 1),
('SMALLCAP', 50.00, NULL, 10000.00, 5000.00, DATEADD(MONTH, 1, GETDATE()), 4, 40, 1),
('LASTUSE', NULL, 20000.00, 0.00, NULL, DATEADD(MONTH, 1, GETDATE()), 9, 10, 1);

INSERT INTO core.app_wallets (total_balance) VALUES (0);

INSERT INTO core.commission_rates (service_type, driver_share, restaurant_share, app_share, effective_from, effective_to) VALUES
('food', 15.00, 75.00, 10.00, DATEADD(MONTH, -1, GETDATE()), NULL),
('taxi', 80.00, NULL, 20.00, DATEADD(MONTH, -1, GETDATE()), NULL),
('food', 16.00, 74.00, 10.00, DATEADD(MONTH, -3, GETDATE()), DATEADD(MONTH, -1, GETDATE()));

DECLARE @role_customer INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @role_driver INT = (SELECT role_id FROM core.roles WHERE role_name = 'driver');
DECLARE @role_staff INT = (SELECT role_id FROM core.roles WHERE role_name = 'restaurant_staff');
DECLARE @role_branch_owner INT = (SELECT role_id FROM core.roles WHERE role_name = 'branch_owner');
DECLARE @role_admin INT = (SELECT role_id FROM core.roles WHERE role_name = 'admin');

INSERT INTO core.users (username, password_hash, first_name, last_name, registration_phone, email, role_id, is_blocked, deleted_at) VALUES
('sara_ahmadi', '$2b$12$hash', 'Sara', 'Ahmadi', '09121234501', 'sara@test.com', @role_customer, 0, NULL),
('reza_karimi', '$2b$12$hash', 'Reza', 'Karimi', '09121234502', 'reza@test.com', @role_customer, 0, NULL),
('mina_hosseini', '$2b$12$hash', 'Mina', 'Hosseini', '09121234503', 'mina@test.com', @role_customer, 1, NULL),
('old_account99', '$2b$12$hash', 'Farhad', 'Ghasemi', '09121234504', 'old@test.com', @role_customer, 0, DATEADD(MONTH, -2, GETDATE())),
('behnam_moshiri', '$2b$12$hash', 'Behnam', 'Moshiri', '09121234505', 'behnam@test.com', @role_customer, 0, NULL),
('driver_neda', '$2b$12$hash', 'Neda', 'Rostami', '09121234507', 'neda@test.com', @role_driver, 0, NULL),
('staff_hamed', '$2b$12$hash', 'Hamed', 'Jafari', '09121234509', 'hamed@test.com', @role_staff, 0, NULL),
('admin_yasaman', '$2b$12$hash', 'Yasaman', 'Bahrami', '09121234512', 'admin@test.com', @role_admin, 0, NULL);

INSERT INTO core.user_wallets (user_id, balance)
SELECT user_id, CASE username WHEN 'sara_ahmadi' THEN 250000.00 WHEN 'reza_karimi' THEN 0.00 ELSE 50000.00 END FROM core.users;

INSERT INTO core.admins (user_id, admin_identifier, access_level)
SELECT user_id, 'ADM-1001', 'full' FROM core.users WHERE username = 'admin_yasaman';
GO


-- PHASE 4: EXECUTE TESTS 

PRINT '=============================================';
PRINT 'STARTING TEST SUITE: core';
PRINT '=============================================';
GO
DELETE FROM test.test_results;
GO


-- Test 1: Math & Functions

PRINT '--- Testing Functions ---';
DECLARE @dist_same_point DECIMAL(10,2) = core.fn_calculate_distance_km(35.6892, 51.3890, 35.6892, 51.3890);
EXEC test.sp_assert_equals 'core', 'fn_calculate_distance_km: same point returns 0', 0.00, @dist_same_point;

DECLARE @dist_tehran_isfahan DECIMAL(10,2) = core.fn_calculate_distance_km(35.6892, 51.3890, 32.6546, 51.6679);
EXEC test.sp_assert_range 'core', 'fn_calculate_distance_km: Tehran to Isfahan is ~340km', @dist_tehran_isfahan, 320.00, 360.00;

DECLARE @admin_user_id INT = (SELECT user_id FROM core.users WHERE username = 'admin_yasaman');
DECLARE @customer_user_id INT = (SELECT user_id FROM core.users WHERE username = 'sara_ahmadi');
DECLARE @actual_1 BIT = core.fn_has_minimum_role_level(@admin_user_id, 5);
EXEC test.sp_assert_equals 'core', 'fn_has_minimum_role_level: admin meets level 5', 1, @actual_1;

DECLARE @actual_2 BIT = core.fn_has_minimum_role_level(@customer_user_id, 5);
EXEC test.sp_assert_equals 'core', 'fn_has_minimum_role_level: customer does NOT meet level 5', 0, @actual_2;

DECLARE @reza_id INT = (SELECT user_id FROM core.users WHERE username = 'reza_karimi');
DECLARE @val_flat50k BIT = core.fn_validate_coupon('FLAT50K', @reza_id, 150000.00);
EXEC test.sp_assert_equals 'core', 'fn_validate_coupon: FLAT50K valid for reza with sufficient order amount', 1, @val_flat50k;
GO


-- Test 2: Write Procedures (Register, Charge, Promote, Coupon)
PRINT '--- Testing Write Procedures ---';
DECLARE @role_customer_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @test_new_user_id INT;

EXEC core.sp_register_user 
    @username = 'newbie_taha', @password_hash = 'hash', @registration_phone = '09121234513', 
    @role_id = @role_customer_id, @new_user_id = @test_new_user_id OUTPUT;

EXEC test.sp_assert_not_null 'core', 'sp_register_user: returns a new_user_id', @test_new_user_id;

DECLARE @actual_wallet_balance DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @test_new_user_id);
EXEC test.sp_assert_equals 'core', 'sp_register_user: wallet was auto-created with 0 balance', 0.00, @actual_wallet_balance;

EXEC core.sp_charge_wallet @user_id = @test_new_user_id, @amount = 150000.00, @payment_method = 'card';
SET @actual_wallet_balance = (SELECT balance FROM core.user_wallets WHERE user_id = @test_new_user_id);
EXEC test.sp_assert_equals 'core', 'sp_charge_wallet: user wallet charged correctly', 150000.00, @actual_wallet_balance;

DECLARE @promote_user_id INT = (SELECT user_id FROM core.users WHERE username = 'driver_neda');
DECLARE @admin_role_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'admin');
EXEC core.sp_assign_admin_role @user_id = @promote_user_id, @admin_identifier = 'ADM-TEST-01', @access_level = 'limited';
DECLARE @actual_role_id INT = (SELECT role_id FROM core.users WHERE user_id = @promote_user_id);
EXEC test.sp_assert_equals 'core', 'sp_assign_admin_role: role_id was synced to admin role', @admin_role_id, @actual_role_id;
GO

-- Test 3: Read APIs

PRINT '--- Testing Read APIs ---';
GO

-- Test: sp_check_user_exists
DECLARE @CheckUserResult TABLE (username_exists BIT, phone_exists BIT, email_exists BIT);
INSERT INTO @CheckUserResult EXEC core.sp_check_user_exists @username = 'sara_ahmadi', @registration_phone = '09121234501', @email = 'sara@test.com';

DECLARE @ue BIT, @pe BIT, @ee BIT;
SELECT TOP 1 @ue = username_exists, @pe = phone_exists, @ee = email_exists FROM @CheckUserResult;
EXEC test.sp_assert_equals 'core', 'sp_check_user_exists: catches existing username', 1, @ue;
EXEC test.sp_assert_equals 'core', 'sp_check_user_exists: catches existing phone', 1, @pe;
EXEC test.sp_assert_equals 'core', 'sp_check_user_exists: catches existing email', 1, @ee;
GO

-- Test: sp_get_user_profile
DECLARE @ProfileResult TABLE (user_id INT, username VARCHAR(50), first_name VARCHAR(50), last_name VARCHAR(50), registration_phone VARCHAR(15), email VARCHAR(100), created_at DATETIME, role_name VARCHAR(20), hierarchy_level INT, balance DECIMAL(10,2));
DECLARE @sara_id INT = (SELECT user_id FROM core.users WHERE username = 'sara_ahmadi');

INSERT INTO @ProfileResult EXEC core.sp_get_user_profile @user_id = @sara_id;

DECLARE @profile_username VARCHAR(50), @profile_balance DECIMAL(10,2);
SELECT TOP 1 @profile_username = username, @profile_balance = balance FROM @ProfileResult;

EXEC test.sp_assert_equals 'core', 'sp_get_user_profile: returns correct username', 'sara_ahmadi', @profile_username;
EXEC test.sp_assert_equals 'core', 'sp_get_user_profile: returns correct wallet balance', 250000.00, @profile_balance;
GO

-- Test: sp_get_available_coupons
DECLARE @CouponsResult TABLE (coupon_id INT, code VARCHAR(20), percentage DECIMAL(5,2), amount DECIMAL(10,2), min_requirement DECIMAL(10,2), max_cap DECIMAL(10,2), expiry_date DATETIME, current_usage INT, max_usage INT, remaining_uses INT);
INSERT INTO @CouponsResult EXEC core.sp_get_available_coupons;

DECLARE @active_coupons_count INT = (SELECT COUNT(*) FROM @CouponsResult);
-- From Seed data: WELCOME20, FLAT50K, HIGHMIN, SMALLCAP, LASTUSE are valid. (5 coupons)
EXEC test.sp_assert_equals 'core', 'sp_get_available_coupons: returns only valid active coupons', 5, @active_coupons_count;
GO

-- Test: sp_verify_login
DECLARE @LoginResult TABLE (is_success INT, message VARCHAR(255), user_id INT, role_id INT);
DECLARE @login_success INT;

-- 1. Valid Login
INSERT INTO @LoginResult EXEC core.sp_verify_login 'sara_ahmadi', '$2b$12$hash';
SELECT TOP 1 @login_success = is_success FROM @LoginResult;
EXEC test.sp_assert_equals 'core', 'sp_verify_login: accepts valid credentials', 1, @login_success;
DELETE FROM @LoginResult;

-- 2. Invalid Password
INSERT INTO @LoginResult EXEC core.sp_verify_login 'sara_ahmadi', 'wrong_hash';
SELECT TOP 1 @login_success = is_success FROM @LoginResult;
EXEC test.sp_assert_equals 'core', 'sp_verify_login: rejects wrong password', 0, @login_success;
DELETE FROM @LoginResult;

-- 3. Blocked User
INSERT INTO @LoginResult EXEC core.sp_verify_login 'mina_hosseini', '$2b$12$hash';
SELECT TOP 1 @login_success = is_success FROM @LoginResult;
EXEC test.sp_assert_equals 'core', 'sp_verify_login: prevents blocked user from logging in', 0, @login_success;
DELETE FROM @LoginResult;

-- 4. Deleted User
INSERT INTO @LoginResult EXEC core.sp_verify_login 'old_account99', '$2b$12$hash';
SELECT TOP 1 @login_success = is_success FROM @LoginResult;
EXEC test.sp_assert_equals 'core', 'sp_verify_login: prevents soft-deleted user from logging in', 0, @login_success;
DELETE FROM @LoginResult;
GO


-- Print Results

EXEC test.sp_print_summary @test_suite = 'core';
GO


-- PHASE 5: FULL TEARDOWN
PRINT '=============================================';
PRINT 'WIPING ALL DATA (PREPARING FOR MAIN PRODUCTION SEED)';
PRINT '=============================================';
GO

DELETE FROM taxi.ride_payments; DELETE FROM taxi.taxi_logs; DELETE FROM taxi.passenger_stats;
DELETE FROM taxi.ride_offer_candidates; DELETE FROM taxi.ride_offers; DELETE FROM taxi.rides;
DELETE FROM taxi.pricing_parameters; DELETE FROM taxi.driver_secondary_phones; 
DELETE FROM taxi.driver_locations; DELETE FROM taxi.driver_wallets; 
DELETE FROM taxi.vehicle_type_services; DELETE FROM taxi.vehicles; DELETE FROM taxi.drivers;

DELETE FROM core.core_logs;
DELETE FROM core.coupon_usages;
DELETE FROM core.complaints;
DELETE FROM core.transactions;
DELETE FROM core.saved_accounts;
DELETE FROM core.addresses;
DELETE FROM core.admins;
DELETE FROM core.user_wallets;
DELETE FROM core.role_permissions;
DELETE FROM core.users;
DELETE FROM core.roles;
DELETE FROM core.permissions;
DELETE FROM core.coupons;
DELETE FROM core.app_wallets;
DELETE FROM core.commission_rates;
GO

DBCC CHECKIDENT ('taxi.taxi_logs', RESEED, 0);
DBCC CHECKIDENT ('taxi.ride_offer_candidates', RESEED, 0);
DBCC CHECKIDENT ('taxi.ride_offers', RESEED, 0); 
DBCC CHECKIDENT ('taxi.rides', RESEED, 0);
DBCC CHECKIDENT ('taxi.pricing_parameters', RESEED, 0); 
DBCC CHECKIDENT ('taxi.driver_secondary_phones', RESEED, 0);
DBCC CHECKIDENT ('taxi.driver_wallets', RESEED, 0); 
DBCC CHECKIDENT ('taxi.vehicles', RESEED, 0);
DBCC CHECKIDENT ('taxi.drivers', RESEED, 0);

DBCC CHECKIDENT ('core.core_logs', RESEED, 0); 
DBCC CHECKIDENT ('core.coupon_usages', RESEED, 0);
DBCC CHECKIDENT ('core.complaints', RESEED, 0); 
DBCC CHECKIDENT ('core.transactions', RESEED, 0);
DBCC CHECKIDENT ('core.saved_accounts', RESEED, 0); 
DBCC CHECKIDENT ('core.addresses', RESEED, 0);
DBCC CHECKIDENT ('core.admins', RESEED, 0); 
DBCC CHECKIDENT ('core.user_wallets', RESEED, 0);
DBCC CHECKIDENT ('core.role_permissions', RESEED, 0); 
DBCC CHECKIDENT ('core.users', RESEED, 0);
DBCC CHECKIDENT ('core.roles', RESEED, 0); 
DBCC CHECKIDENT ('core.permissions', RESEED, 0);
DBCC CHECKIDENT ('core.coupons', RESEED, 0); 
DBCC CHECKIDENT ('core.app_wallets', RESEED, 0);
DBCC CHECKIDENT ('core.commission_rates', RESEED, 0);
GO

PRINT 'Full wipe complete. Database is 100% clean and ready for Production Seed.';
GO