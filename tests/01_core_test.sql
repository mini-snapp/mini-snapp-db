USE mini_snapp;
GO

PRINT '=============================================';
PRINT 'STARTING TEST SUITE: core';
PRINT '=============================================';
GO
-- reset result test
DELETE FROM test.test_results
GO
-- functions

PRINT '--- Testing fn_calculate_distance_km ---';
GO

DECLARE @dist_same_point DECIMAL(10,2);
SET @dist_same_point = core.fn_calculate_distance_km(35.6892, 51.3890, 35.6892, 51.3890);
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'fn_calculate_distance_km: same point returns 0',
    @expected = 0.00,
    @actual = @dist_same_point;

DECLARE @dist_tehran_isfahan DECIMAL(10,2);
SET @dist_tehran_isfahan = core.fn_calculate_distance_km(35.6892, 51.3890, 32.6546, 51.6679);
EXEC test.sp_assert_range
    @test_suite = 'core',
    @test_name = 'fn_calculate_distance_km: Tehran to Isfahan is ~340km',
    @actual = @dist_tehran_isfahan,
    @min_expected = 320.00,
    @max_expected = 360.00;
GO


PRINT '--- Testing fn_has_minimum_role_level ---';
GO

DECLARE @admin_user_id INT = (SELECT user_id FROM core.users WHERE username = 'admin_yasaman');
DECLARE @customer_user_id INT = (SELECT user_id FROM core.users WHERE username = 'sara_ahmadi');

DECLARE @actual_1 BIT = core.fn_has_minimum_role_level(@admin_user_id, 5);
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'fn_has_minimum_role_level: admin meets level 5',
    @expected = 1,
    @actual = @actual_1;


DECLARE @actual_2 BIT = core.fn_has_minimum_role_level(@customer_user_id, 5);
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'fn_has_minimum_role_level: customer does NOT meet level 5',
    @expected = 0,
    @actual = @actual_2;

DECLARE @actual_3 BIT = core.fn_has_minimum_role_level(@customer_user_id, 1);
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'fn_has_minimum_role_level: customer meets level 1 (own level)',
    @expected = 1,
    @actual = @actual_3;
GO


PRINT '--- Testing fn_get_active_commission_rate ---';
GO

DECLARE @food_driver_share DECIMAL(5,2);
SELECT @food_driver_share = driver_share FROM core.fn_get_active_commission_rate('food', NULL);

DECLARE @food_driver_share_direct DECIMAL(5,2);
SELECT TOP 1 @food_driver_share_direct = driver_share
FROM core.commission_rates
WHERE service_type = 'food' AND effective_from <= GETDATE() AND (effective_to IS NULL OR effective_to > GETDATE())
ORDER BY effective_from DESC;

EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'fn_get_active_commission_rate: current food rate matches direct table lookup',
    @expected = @food_driver_share_direct,
    @actual = @food_driver_share;

DECLARE @taxi_app_share DECIMAL(5,2);
SELECT @taxi_app_share = app_share FROM core.fn_get_active_commission_rate('taxi', NULL);

DECLARE @taxi_app_share_direct DECIMAL(5,2);
SELECT TOP 1 @taxi_app_share_direct = app_share
FROM core.commission_rates
WHERE service_type = 'taxi' AND effective_from <= GETDATE() AND (effective_to IS NULL OR effective_to > GETDATE())
ORDER BY effective_from DESC;

EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'fn_get_active_commission_rate: current taxi rate matches direct table lookup',
    @expected = @taxi_app_share_direct,
    @actual = @taxi_app_share;

DECLARE @check_date DATETIME = DATEADD(MONTH, -4, GETDATE());
DECLARE @historical_share DECIMAL(5,2);
SELECT @historical_share = driver_share FROM core.fn_get_active_commission_rate('food', @check_date);

DECLARE @historical_share_direct DECIMAL(5,2);
SELECT TOP 1 @historical_share_direct = driver_share
FROM core.commission_rates
WHERE service_type = 'food' AND effective_from <= @check_date AND (effective_to IS NULL OR effective_to > @check_date)
ORDER BY effective_from DESC;

EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'fn_get_active_commission_rate: historical food rate matches direct table lookup',
    @expected = @historical_share_direct,
    @actual = @historical_share;
GO


PRINT '--- Testing fn_validate_coupon ---';
GO

DECLARE @sara_id INT = (SELECT user_id FROM core.users WHERE username = 'sara_ahmadi');
DECLARE @reza_id INT = (SELECT user_id FROM core.users WHERE username = 'reza_karimi');


DECLARE @val_flat50k BIT = core.fn_validate_coupon('FLAT50K', @reza_id, 150000.00);
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'fn_validate_coupon: FLAT50K valid for reza with sufficient order amount',
    @expected = 1,
    @actual = @val_flat50k;

DECLARE @val_expired BIT = core.fn_validate_coupon('EXPIRED10', @reza_id, 50000.00);
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'fn_validate_coupon: EXPIRED10 is invalid (expired)',
    @expected = 0,
    @actual = @val_expired;

DECLARE @val_maxed BIT = core.fn_validate_coupon('MAXEDOUT', @reza_id, 50000.00);
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'fn_validate_coupon: MAXEDOUT is invalid (usage limit reached)',
    @expected = 0,
    @actual = @val_maxed;

DECLARE @val_disabled BIT = core.fn_validate_coupon('DISABLED5', @reza_id, 50000.00);
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'fn_validate_coupon: DISABLED5 is invalid (is_active = 0)',
    @expected = 0,
    @actual = @val_disabled;

DECLARE @val_highmin BIT = core.fn_validate_coupon('HIGHMIN', @reza_id, 10000.00);
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'fn_validate_coupon: HIGHMIN invalid when order amount is too low',
    @expected = 0,
    @actual = @val_highmin;

DECLARE @val_notexist BIT = core.fn_validate_coupon('DOESNOTEXIST', @reza_id, 50000.00);
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'fn_validate_coupon: non-existent coupon code is invalid',
    @expected = 0,
    @actual = @val_notexist;

DECLARE @val_welcome BIT = core.fn_validate_coupon('WELCOME20', @sara_id, 60000.00);
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'fn_validate_coupon: WELCOME20 invalid for sara (already used)',
    @expected = 0,
    @actual = @val_welcome;
GO



-- Stored Procedures


PRINT '--- Testing sp_register_user ---';
GO

DECLARE @role_customer_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @test_new_user_id INT;

EXEC core.sp_register_user
    @username = 'test_user_unit1',
    @password_hash = '$2b$12$testhash000000000000000000000001',
    @first_name = 'Test', @last_name = 'UserOne',
    @registration_phone = '09120000001', @email = 'testuser1@example.com',
    @role_id = @role_customer_id,
    @new_user_id = @test_new_user_id OUTPUT;

EXEC test.sp_assert_not_null
    @test_suite = 'core',
    @test_name = 'sp_register_user: returns a new_user_id',
    @value = @test_new_user_id;

DECLARE @actual_username VARCHAR(50) = (SELECT username FROM core.users WHERE user_id = @test_new_user_id);
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'sp_register_user: username was correctly inserted',
    @expected = 'test_user_unit1',
    @actual = @actual_username;

DECLARE @actual_wallet_balance DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @test_new_user_id);
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'sp_register_user: wallet was auto-created with balance 0',
    @expected = 0.00,
    @actual = @actual_wallet_balance;
GO


PRINT '--- Testing sp_charge_wallet ---';
GO

DECLARE @charge_test_user_id INT = (SELECT user_id FROM core.users WHERE username = 'test_user_unit1');
DECLARE @balance_before DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @charge_test_user_id);

EXEC core.sp_charge_wallet
    @user_id = @charge_test_user_id,
    @amount = 200000.00,
    @payment_method = 'card';

DECLARE @balance_after DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @charge_test_user_id);


DECLARE @balance_diff DECIMAL(10,2) = @balance_after - @balance_before;
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'sp_charge_wallet: balance increased by exactly the charge amount',
    @expected = 200000.00,
    @actual = @balance_diff;


DECLARE @cond_transaction BIT = (SELECT CASE WHEN EXISTS (
    SELECT 1 FROM core.transactions
    WHERE user_id = @charge_test_user_id
      AND transaction_type = 'wallet_charge'

      AND transaction_status = 'completed' 
      AND amount = 200000.00
) THEN 1 ELSE 0 END);

EXEC test.sp_assert_true
    @test_suite = 'core',
    @test_name = 'sp_charge_wallet: a completed wallet_charge transaction was recorded',
    @condition = @cond_transaction;

BEGIN TRY
    EXEC core.sp_charge_wallet
        @user_id = @charge_test_user_id,
        @amount = -500.00,
        @payment_method = 'card';

    EXEC test.sp_assert_true
        @test_suite = 'core',
        @test_name = 'sp_charge_wallet: negative amount should raise an error (did NOT raise — FAIL)',
        @condition = 0;
END TRY
BEGIN CATCH
    EXEC test.sp_assert_true
        @test_suite = 'core',
        @test_name = 'sp_charge_wallet: negative amount correctly raises an error',
        @condition = 1;
END CATCH
GO


PRINT '--- Testing sp_assign_admin_role ---';
GO

DECLARE @promote_user_id INT = (SELECT user_id FROM core.users WHERE username = 'driver_neda');
DECLARE @admin_role_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'admin');

EXEC core.sp_assign_admin_role
    @user_id = @promote_user_id,
    @admin_identifier = 'ADM-TEST-01',
    @access_level = 'limited';

DECLARE @cond_admin_row BIT = (SELECT CASE WHEN EXISTS (
    SELECT 1 FROM core.admins WHERE user_id = @promote_user_id AND admin_identifier = 'ADM-TEST-01'
) THEN 1 ELSE 0 END);

EXEC test.sp_assert_true
    @test_suite = 'core',
    @test_name = 'sp_assign_admin_role: admins row created for promoted user',
    @condition = @cond_admin_row;

DECLARE @actual_role_id INT = (SELECT role_id FROM core.users WHERE user_id = @promote_user_id);
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'sp_assign_admin_role: role_id was synced to admin role',
    @expected = @admin_role_id,
    @actual = @actual_role_id;

BEGIN TRY
    EXEC core.sp_assign_admin_role
        @user_id = @promote_user_id,
        @admin_identifier = 'ADM-TEST-02',
        @access_level = 'full';

    EXEC test.sp_assert_true
        @test_suite = 'core',
        @test_name = 'sp_assign_admin_role: double-promotion should raise an error (did NOT raise — FAIL)',
        @condition = 0;
END TRY
BEGIN CATCH
    EXEC test.sp_assert_true
        @test_suite = 'core',
        @test_name = 'sp_assign_admin_role: double-promotion correctly raises an error',
        @condition = 1;
END CATCH
GO


PRINT '--- Testing sp_apply_coupon ---';
GO

DECLARE @coupon_test_user_id INT = (SELECT user_id FROM core.users WHERE username = 'behnam_moshiri');
DECLARE @usage_before INT = (SELECT current_usage FROM core.coupons WHERE code = 'SMALLCAP');

EXEC core.sp_apply_coupon
    @coupon_code = 'SMALLCAP',
    @user_id = @coupon_test_user_id,
    @order_amount = 15000.00,
    @order_id = 8888,
    @ride_id = NULL;

DECLARE @usage_after INT = (SELECT current_usage FROM core.coupons WHERE code = 'SMALLCAP');

DECLARE @usage_diff INT = @usage_after - @usage_before;
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'sp_apply_coupon: current_usage incremented by 1',
    @expected = 1,
    @actual = @usage_diff;

DECLARE @cond_coupon_usage BIT = (SELECT CASE WHEN EXISTS (
    SELECT 1 FROM core.coupon_usages cu
    JOIN core.coupons c ON cu.coupon_id = c.coupon_id
    WHERE c.code = 'SMALLCAP' AND cu.user_id = @coupon_test_user_id AND cu.order_id = 8888
) THEN 1 ELSE 0 END);

EXEC test.sp_assert_true
    @test_suite = 'core',
    @test_name = 'sp_apply_coupon: coupon_usages row was created',
    @condition = @cond_coupon_usage;

BEGIN TRY
    EXEC core.sp_apply_coupon
        @coupon_code = 'EXPIRED10',
        @user_id = @coupon_test_user_id,
        @order_amount = 50000.00,
        @order_id = 8889,
        @ride_id = NULL;

    EXEC test.sp_assert_true
        @test_suite = 'core',
        @test_name = 'sp_apply_coupon: expired coupon should raise an error (did NOT raise — FAIL)',
        @condition = 0;
END TRY
BEGIN CATCH
    EXEC test.sp_assert_true
        @test_suite = 'core',
        @test_name = 'sp_apply_coupon: expired coupon correctly raises an error',
        @condition = 1;
END CATCH

BEGIN TRY
    EXEC core.sp_apply_coupon
        @coupon_code = 'BRANDNEW',
        @user_id = @coupon_test_user_id,
        @order_amount = 50000.00,
        @order_id = NULL,
        @ride_id = NULL;

    EXEC test.sp_assert_true
        @test_suite = 'core',
        @test_name = 'sp_apply_coupon: missing order_id AND ride_id should raise an error (did NOT raise — FAIL)',
        @condition = 0;
END TRY
BEGIN CATCH
    EXEC test.sp_assert_true
        @test_suite = 'core',
        @test_name = 'sp_apply_coupon: missing order_id AND ride_id correctly raises an error',
        @condition = 1;
END CATCH
GO



--Triggers (verified indirectly via their side effects)


PRINT '--- Testing trg_users_after_insert (via core_logs) ---';
GO

DECLARE @logged_user_id INT = (SELECT user_id FROM core.users WHERE username = 'test_user_unit1');

DECLARE @cond_user_log BIT = (SELECT CASE WHEN EXISTS (
    SELECT 1 FROM core.core_logs
    WHERE target_table = 'users' AND target_id = CAST(@logged_user_id AS VARCHAR) AND operation_type = 'insert'
) THEN 1 ELSE 0 END);

EXEC test.sp_assert_true
    @test_suite = 'core',
    @test_name = 'trg_users_after_insert: a log entry exists for the new user registration',
    @condition = @cond_user_log;
GO


PRINT '--- Testing trg_transactions_after_insert (via core_logs) ---';
GO

DECLARE @cond_trans_log BIT = (SELECT CASE WHEN EXISTS (
    SELECT 1 FROM core.core_logs WHERE target_table = 'transactions'
) THEN 1 ELSE 0 END);

EXEC test.sp_assert_true
    @test_suite = 'core',
    @test_name = 'trg_transactions_after_insert: a log entry exists for at least one transaction',
    @condition = @cond_trans_log;
GO


PRINT '--- Testing trg_coupons_after_update (auto-deactivation) ---';
GO

DECLARE @autotest_coupon_id INT = (SELECT coupon_id FROM core.coupons WHERE code = 'LASTUSE');

UPDATE core.coupons
SET current_usage = max_usage
WHERE coupon_id = @autotest_coupon_id;

DECLARE @actual_is_active BIT = (SELECT is_active FROM core.coupons WHERE coupon_id = @autotest_coupon_id);
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'trg_coupons_after_update: coupon auto-deactivated when usage limit reached',
    @expected = 0,
    @actual = @actual_is_active;
GO



-- Views


PRINT '--- Testing vw_active_coupons ---';
GO

DECLARE @count_expired INT = (SELECT COUNT(*) FROM core.vw_active_coupons WHERE code = 'EXPIRED10');
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'vw_active_coupons: EXPIRED10 does not appear (expired)',
    @expected = 0,
    @actual = @count_expired;

DECLARE @count_disabled INT = (SELECT COUNT(*) FROM core.vw_active_coupons WHERE code = 'DISABLED5');
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'vw_active_coupons: DISABLED5 does not appear (inactive)',
    @expected = 0,
    @actual = @count_disabled;

DECLARE @count_welcome INT = (SELECT COUNT(*) FROM core.vw_active_coupons WHERE code = 'WELCOME20');
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'vw_active_coupons: WELCOME20 appears correctly',
    @expected = 1,
    @actual = @count_welcome;
GO


PRINT '--- Testing vw_wallet_summary ---';
GO

DECLARE @sara_wallet_id INT = (SELECT user_id FROM core.users WHERE username = 'sara_ahmadi');
DECLARE @sara_balance_direct DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @sara_wallet_id);

DECLARE @vw_sara_balance DECIMAL(10,2) = (SELECT balance FROM core.vw_wallet_summary WHERE user_id = @sara_wallet_id);
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'vw_wallet_summary: balance matches user_wallets table directly',
    @expected = @sara_balance_direct,
    @actual = @vw_sara_balance;
GO


PRINT '--- Testing vw_open_complaints ---';
GO

DECLARE @count_resolved INT = (SELECT COUNT(*) FROM core.vw_open_complaints WHERE complaint_status IN ('resolved','rejected'));
EXEC test.sp_assert_equals
    @test_suite = 'core',
    @test_name = 'vw_open_complaints: only open/in_review complaints are shown',
    @expected = 0,
    @actual = @count_resolved;

DECLARE @cond_open_complaints BIT = (SELECT CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END FROM core.vw_open_complaints);
EXEC test.sp_assert_true
    @test_suite = 'core',
    @test_name = 'vw_open_complaints: at least one open complaint exists',
    @condition = @cond_open_complaints;
GO


PRINT '--- Testing vw_user_roles_permissions ---';
GO

DECLARE @admin_check_id INT = (SELECT user_id FROM core.users WHERE username = 'admin_yasaman');

DECLARE @cond_admin_perm BIT = (SELECT CASE WHEN EXISTS (
    SELECT 1 FROM core.vw_user_roles_permissions
    WHERE user_id = @admin_check_id AND permissions_name = 'can_ban_user'
) THEN 1 ELSE 0 END);

EXEC test.sp_assert_true
    @test_suite = 'core',
    @test_name = 'vw_user_roles_permissions: admin_yasaman has can_ban_user permission',
    @condition = @cond_admin_perm;
GO



-- summary

EXEC test.sp_print_summary @test_suite = 'core';
GO


-- CLEANUP


PRINT '=============================================';
PRINT 'CLEANING UP TEST DATA';
PRINT '=============================================';
GO

DECLARE @cleanup_smallcap_id INT = (SELECT coupon_id FROM core.coupons WHERE code = 'SMALLCAP');
DECLARE @cleanup_coupon_user_id INT = (SELECT user_id FROM core.users WHERE username = 'behnam_moshiri');

DELETE FROM core.coupon_usages
WHERE coupon_id = @cleanup_smallcap_id AND user_id = @cleanup_coupon_user_id AND order_id = 8888;

UPDATE core.coupons
SET current_usage = current_usage - 1
WHERE coupon_id = @cleanup_smallcap_id;
GO

UPDATE core.coupons
SET current_usage = 9, is_active = 1
WHERE code = 'LASTUSE';
GO

DECLARE @cleanup_neda_id INT = (SELECT user_id FROM core.users WHERE username = 'driver_neda');
DECLARE @cleanup_driver_role_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'driver');

DELETE FROM core.admins WHERE user_id = @cleanup_neda_id AND admin_identifier = 'ADM-TEST-01';

UPDATE core.users
SET role_id = @cleanup_driver_role_id
WHERE user_id = @cleanup_neda_id;
GO

DECLARE @cleanup_test_user_id INT = (SELECT user_id FROM core.users WHERE username = 'test_user_unit1');

DELETE FROM core.core_logs WHERE actor_id = @cleanup_test_user_id;
DELETE FROM core.transactions WHERE user_id = @cleanup_test_user_id;
DELETE FROM core.user_wallets WHERE user_id = @cleanup_test_user_id;
DELETE FROM core.users WHERE user_id = @cleanup_test_user_id;
GO


PRINT 'Cleanup complete. Seed data restored to its original state.';
GO