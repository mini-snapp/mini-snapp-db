USE mini_snapp;
GO


PRINT '--- SCENARIO 2 | STEP 1: Setup Demo User ---';
DECLARE @customer_role_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @w_user_id INT;
EXEC core.sp_register_user 'wallet_demo', 'hash', 'W', 'Demo', '09102223344', NULL, @customer_role_id, @w_user_id OUTPUT;

PRINT '--- SCENARIO 2 | STEP 2: Successful Wallet Charge ---';

DECLARE @uid INT = (SELECT user_id FROM core.users WHERE username = 'wallet_demo');
EXEC core.sp_charge_wallet @user_id = @uid, @amount = 30.00, @payment_method = 'card';


SELECT username, balance FROM core.vw_wallet_summary WHERE username = 'wallet_demo';

PRINT '--- SCENARIO 2 | STEP 3: Audit & Transaction Logs ---';

SELECT transaction_type, transaction_status, amount, payment_method 
FROM core.transactions WHERE user_id = @uid;

PRINT '--- SCENARIO 2 | STEP 4: Edge Case - Negative Charge ---';

BEGIN TRY
    EXEC core.sp_charge_wallet @user_id = @uid, @amount = -50.00, @payment_method = 'card';
END TRY
BEGIN CATCH

    SELECT ERROR_MESSAGE() AS Security_Alert, 'Negative amount blocked!' AS Status;
END CATCH
GO


PRINT '--- SCENARIO 3 | STEP 1: Create a Limited Coupon ---';

INSERT INTO core.coupons (code, amount, current_usage, max_usage, is_active)
VALUES ('DEMO_MAX2', 10.00, 0, 2, 1);


SELECT code, amount, current_usage, max_usage, remaining_uses FROM core.vw_active_coupons WHERE code = 'DEMO_MAX2';

PRINT '--- SCENARIO 3 | STEP 2: First User Applies Coupon ---';
DECLARE @u1 INT = (SELECT user_id FROM core.users WHERE username = 'wallet_demo');
EXEC core.sp_apply_coupon @coupon_code = 'DEMO_MAX2', @user_id = @u1, @order_amount = 50.00, @order_id = 999;


SELECT code, current_usage, max_usage FROM core.coupons WHERE code = 'DEMO_MAX2';

PRINT '--- SCENARIO 3 | STEP 3: Second User Applies Coupon (Max Reached) ---';

DECLARE @customer_role_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @u2 INT;
EXEC core.sp_register_user 'coupon_user2', 'hash', 'C2', 'Demo', '09102223355', NULL, @customer_role_id, @u2 OUTPUT;

EXEC core.sp_apply_coupon @coupon_code = 'DEMO_MAX2', @user_id = @u2, @order_amount = 50.00, @order_id = 1000;


SELECT code, current_usage, max_usage, CAST(is_active AS INT) AS is_active_status 
FROM core.coupons WHERE code = 'DEMO_MAX2';

PRINT '--- SCENARIO 3 | STEP 4: Third User Tries to Apply (Should Fail) ---';

DECLARE @u3 INT;
EXEC core.sp_register_user 'coupon_user3', 'hash', 'C3', 'Demo', '09102223366', NULL, @customer_role_id, @u3 OUTPUT;

BEGIN TRY
    EXEC core.sp_apply_coupon @coupon_code = 'DEMO_MAX2', @user_id = @u3, @order_amount = 50.00, @order_id = 1001;
END TRY
BEGIN CATCH

    SELECT ERROR_MESSAGE() AS System_Message, 'Coupon logic works perfectly!' AS Conclusion;
END CATCH
GO