USE mini_snapp;
GO

PRINT '--- SCENARIO 2 | STEP 1: Setup Demo User ---';
DECLARE @customer_role_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @w_user_id INT;
EXEC core.sp_register_user 'wallet_demo', 'hash', 'Liam', 'Carter', '09102223344', NULL, @customer_role_id, @w_user_id OUTPUT;

PRINT '--- SCENARIO 2 | STEP 2: Successful Wallet Charge ---';
DECLARE @uid INT = (SELECT user_id FROM core.users WHERE username = 'wallet_demo');
EXEC core.sp_charge_wallet @user_id = @uid, @amount = 60.00, @payment_method = 'card';

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

SELECT code, amount, current_usage, max_usage, remaining_uses
FROM core.vw_active_coupons WHERE code = 'DEMO_MAX2';

-- Ensure at least one branch exists so real orders can be referenced by FK
IF NOT EXISTS (SELECT 1 FROM food.branches)
BEGIN
    INSERT INTO food.brands (name, commission_rate) VALUES ('Demo Bistro', 0.1500);
    DECLARE @b_id INT = SCOPE_IDENTITY();
    INSERT INTO food.branches (brand_id, province, city, street, latitude, longitude, food_type, max_delivery_distance)
    VALUES (@b_id, 'Tehran', 'Tehran', 'Valiasr Ave', 35.71000000, 51.40000000, 'Bistro', 8.00);
END

DECLARE @target_branch INT = (SELECT TOP 1 branch_id FROM food.branches);

PRINT '--- SCENARIO 3 | STEP 2: First User Applies Coupon ---';
DECLARE @u1 INT = (SELECT user_id FROM core.users WHERE username = 'wallet_demo');
INSERT INTO food.food_orders (customer_id, branch_id, delivery_fee, final_price, allocated_discount, is_takeout, status)
VALUES (@u1, @target_branch, 0.00, 50.00, 0.00, 1, 'pending');
DECLARE @ord1 INT = SCOPE_IDENTITY();

EXEC core.sp_apply_coupon @coupon_code = 'DEMO_MAX2', @user_id = @u1, @order_amount = 50.00, @order_id = @ord1;
SELECT code, current_usage, max_usage FROM core.coupons WHERE code = 'DEMO_MAX2';

PRINT '--- SCENARIO 3 | STEP 3: Second User Applies Coupon (Max Reached) ---';
DECLARE @customer_role_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @u2 INT;
EXEC core.sp_register_user 'coupon_user2', 'hash', 'Maya', 'Lin', '09102223355', NULL, @customer_role_id, @u2 OUTPUT;

INSERT INTO food.food_orders (customer_id, branch_id, delivery_fee, final_price, allocated_discount, is_takeout, status)
VALUES (@u2, @target_branch, 0.00, 50.00, 0.00, 1, 'pending');
DECLARE @ord2 INT = SCOPE_IDENTITY();

EXEC core.sp_apply_coupon @coupon_code = 'DEMO_MAX2', @user_id = @u2, @order_amount = 50.00, @order_id = @ord2;

SELECT code, current_usage, max_usage, CAST(is_active AS INT) AS is_active_status
FROM core.coupons WHERE code = 'DEMO_MAX2';

PRINT '--- SCENARIO 3 | STEP 4: Third User Tries to Apply (Should Fail) ---';
DECLARE @u3 INT;
EXEC core.sp_register_user 'coupon_user3', 'hash', 'Noah', 'Reed', '09102223366', NULL, @customer_role_id, @u3 OUTPUT;

INSERT INTO food.food_orders (customer_id, branch_id, delivery_fee, final_price, allocated_discount, is_takeout, status)
VALUES (@u3, @target_branch, 0.00, 50.00, 0.00, 1, 'pending');
DECLARE @ord3 INT = SCOPE_IDENTITY();

BEGIN TRY
    EXEC core.sp_apply_coupon @coupon_code = 'DEMO_MAX2', @user_id = @u3, @order_amount = 50.00, @order_id = @ord3;
END TRY
BEGIN CATCH
    SELECT ERROR_MESSAGE() AS System_Message, 'Exhausted coupon rejected as expected!' AS Conclusion;
END CATCH
GO
