USE mini_snapp;
GO

IF OBJECT_ID('food.sp_cancel_order', 'P') IS NOT NULL
    DROP PROCEDURE food.sp_cancel_order;
GO

CREATE PROCEDURE food.sp_cancel_order
    @order_id INT,
    @actor_type VARCHAR(10),
    @reason VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    IF food.fn_can_cancel_order(@order_id, @actor_type) = 0
    BEGIN
        RAISERROR('this order cannot be cancelled', 16, 1);
        RETURN;
    END
    DECLARE @customer_id INT, @charged_amount DECIMAL(10,2), @has_payment BIT = 0;
    SELECT @customer_id = fo.customer_id
    FROM food.food_orders fo
    WHERE fo.order_id = @order_id;
    SELECT @charged_amount = t.amount, @has_payment = 1
    FROM food.order_payments op JOIN core.transactions t ON t.transaction_id = op.transaction_id
    WHERE op.order_id = @order_id;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE food.food_orders
        SET status = 'cancelled', rejection_reason = @reason
        WHERE order_id = @order_id;
        IF @has_payment = 1
        BEGIN
            EXEC core.sp_charge_wallet
                @user_id = @customer_id,
                @amount = @charged_amount,
                @payment_method = 'refund';
            INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
            VALUES (@customer_id, 'refund', 'completed', @charged_amount, 'wallet', NULL, SYSDATETIME());
        END
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END

GO

CREATE PROCEDURE food.sp_clear_cart
    @user_id INT, @branch_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM food.cart_items WHERE user_id = @user_id AND (@branch_id IS NULL OR branch_id = @branch_id);
END
GO

CREATE PROCEDURE food.sp_set_branch_schedule
    @branch_id INT, @day_of_week INT, @start_time TIME, @end_time TIME, @is_closed BIT
AS
BEGIN
    SET NOCOUNT ON;
    IF @day_of_week NOT BETWEEN 0 AND 6
    BEGIN
        RAISERROR('day of week must be between 0 and 6', 16, 1);
        RETURN;
    END
    MERGE food.work_schedules AS target
    USING (SELECT @branch_id AS branch_id, @day_of_week AS day_of_week) AS src
        ON target.branch_id = src.branch_id AND target.day_of_week = src.day_of_week
    WHEN MATCHED THEN UPDATE SET start_time = @start_time, end_time = @end_time, is_closed = @is_closed
    WHEN NOT MATCHED THEN INSERT (branch_id, day_of_week, start_time, end_time, is_closed)
        VALUES (@branch_id, @day_of_week, @start_time, @end_time, @is_closed);
END

GO

IF OBJECT_ID('food.sp_create_menu_discount', 'P') IS NOT NULL
    DROP PROCEDURE food.sp_create_menu_discount;
GO

CREATE PROCEDURE food.sp_create_menu_discount
    @menu_item_id INT, @percentage DECIMAL(5,2) = NULL, @amount DECIMAL(10,2) = NULL,
    @start_at DATETIME2, @end_at DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO food.menu_discounts (menu_item_id, percentage, amount, start_at, end_at, is_active)
    VALUES (@menu_item_id, @percentage, @amount, @start_at, @end_at, 1);
END

GO


CREATE PROCEDURE food.sp_get_available_branches_for_customer
    @user_lat DECIMAL(9,6), @user_lng DECIMAL(9,6), @radius_km DECIMAL(9,3), @check_datetime DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @check_datetime IS NULL SET @check_datetime = SYSDATETIME();
    SELECT d.branch_id, d.brand_id, d.city, d.food_type, d.distance_km
    FROM food.fn_branches_within_distance(@user_lat, @user_lng, @radius_km) d
    WHERE food.fn_is_branch_open(d.branch_id, @check_datetime) = 1
    ORDER BY d.distance_km ASC;
END
GO

CREATE PROCEDURE food.sp_assign_restaurant_staff
    @user_id INT, @branch_id INT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM food.restaurant_staff WHERE user_id = @user_id AND branch_id = @branch_id)
    BEGIN
        RAISERROR('this user is already assigned as staff at this branch', 16, 1);
        RETURN;
    END
    IF EXISTS (SELECT 1 FROM food.branch_owners WHERE user_id = @user_id AND branch_id = @branch_id)
    BEGIN
        RAISERROR('this user already owns this branch and does not need a staff assignment', 16, 1);
        RETURN;
    END
    INSERT INTO food.restaurant_staff (user_id, branch_id) VALUES (@user_id, @branch_id);
END

GO