USE mini_snapp;
GO

CREATE OR ALTER PROCEDURE food.sp_cancel_order
    @order_id INT,
    @actor_type VARCHAR(10),
    @reason VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    IF food.fn_can_cancel_order(@order_id, @actor_type) = 0
    BEGIN
        RAISERROR('This order cannot be cancelled at its current stage.', 16, 1);
        RETURN;
    END

    DECLARE @customer_id INT;
    DECLARE @branch_id INT;
    DECLARE @delivery_fee DECIMAL(10,2);
    DECLARE @allocated_discount DECIMAL(10,2);
    DECLARE @charged_amount DECIMAL(10,2) = 0;

    SELECT
        @customer_id = fo.customer_id,
        @branch_id = fo.branch_id,
        @delivery_fee = fo.delivery_fee,
        @allocated_discount = fo.allocated_discount
    FROM food.food_orders fo
    WHERE fo.order_id = @order_id;

    SELECT @charged_amount = ISNULL(SUM(t.amount), 0)
    FROM food.order_payments op
    JOIN core.transactions t ON t.transaction_id = op.transaction_id
    WHERE op.order_id = @order_id
      AND t.transaction_status = 'completed';

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE food.food_orders
        SET status = 'cancelled',
            rejection_reason = @reason
        WHERE order_id = @order_id;

        IF @charged_amount > 0
        BEGIN
            UPDATE core.user_wallets
            SET balance = balance + @charged_amount
            WHERE user_id = @customer_id;

            INSERT INTO core.transactions
                (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
            VALUES
                (@customer_id, 'refund', 'completed', @charged_amount, 'wallet', NULL, SYSDATETIME());

            DECLARE @commission_rate DECIMAL(5,4);
            SELECT @commission_rate = br.commission_rate
            FROM food.branches b
            JOIN food.brands br ON br.brand_id = b.brand_id
            WHERE b.branch_id = @branch_id;

            IF @commission_rate IS NULL
                SELECT @commission_rate = app_share / 100.0
                FROM core.fn_get_active_commission_rate('food', NULL);

            DECLARE @food_portion DECIMAL(10,2) = @charged_amount - @delivery_fee + ISNULL(@allocated_discount, 0);
            IF @food_portion < 0 SET @food_portion = 0;

            DECLARE @restaurant_reversal DECIMAL(10,2) = ROUND(@food_portion * (1 - ISNULL(@commission_rate, 0)), 2);
            DECLARE @app_reversal DECIMAL(10,2) = @food_portion - @restaurant_reversal;

            UPDATE food.branch_wallets
            SET balance = CASE WHEN balance >= @restaurant_reversal THEN balance - @restaurant_reversal ELSE 0 END
            WHERE branch_id = @branch_id;

            UPDATE TOP (1) core.app_wallets
            SET total_balance = CASE WHEN total_balance >= @app_reversal THEN total_balance - @app_reversal ELSE 0 END;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        ;THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE food.sp_clear_cart
    @user_id INT,
    @branch_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM food.cart_items
    WHERE user_id = @user_id
      AND (@branch_id IS NULL OR branch_id = @branch_id);
END
GO

CREATE OR ALTER PROCEDURE food.sp_set_branch_schedule
    @branch_id INT,
    @day_of_week INT,
    @start_time TIME,
    @end_time TIME,
    @is_closed BIT
AS
BEGIN
    SET NOCOUNT ON;
    IF @day_of_week NOT BETWEEN 0 AND 6
    BEGIN
        RAISERROR('Day of week must be between 0 and 6.', 16, 1);
        RETURN;
    END

    MERGE food.work_schedules AS target
    USING (SELECT @branch_id AS branch_id, @day_of_week AS day_of_week) AS src
        ON target.branch_id = src.branch_id AND target.day_of_week = src.day_of_week
    WHEN MATCHED THEN
        UPDATE SET start_time = @start_time, end_time = @end_time, is_closed = @is_closed
    WHEN NOT MATCHED THEN
        INSERT (branch_id, day_of_week, start_time, end_time, is_closed)
        VALUES (@branch_id, @day_of_week, @start_time, @end_time, @is_closed);
END
GO

CREATE OR ALTER PROCEDURE food.sp_create_menu_discount
    @menu_item_id INT,
    @percentage DECIMAL(5,2) = NULL,
    @amount DECIMAL(10,2) = NULL,
    @start_at DATETIME2,
    @end_at DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO food.menu_discounts (menu_item_id, percentage, amount, start_at, end_at, is_active)
    VALUES (@menu_item_id, @percentage, @amount, @start_at, @end_at, 1);
END
GO

CREATE OR ALTER PROCEDURE food.sp_get_available_branches_for_customer
    @user_lat DECIMAL(10,8),
    @user_lng DECIMAL(11,8),
    @radius_km DECIMAL(9,3),
    @check_datetime DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @check_datetime IS NULL
        SET @check_datetime = SYSDATETIME();

    SELECT d.branch_id, d.brand_id, d.city, d.food_type, d.distance_km
    FROM food.fn_branches_within_distance(@user_lat, @user_lng, @radius_km) d
    WHERE food.fn_is_branch_open(d.branch_id, @check_datetime) = 1
    ORDER BY d.distance_km ASC;
END
GO

CREATE OR ALTER PROCEDURE food.sp_assign_restaurant_staff
    @user_id INT,
    @branch_id INT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM food.restaurant_staff WHERE user_id = @user_id AND branch_id = @branch_id)
    BEGIN
        RAISERROR('This user is already assigned as staff at this branch.', 16, 1);
        RETURN;
    END
    IF EXISTS (SELECT 1 FROM food.branch_owners WHERE user_id = @user_id AND branch_id = @branch_id)
    BEGIN
        RAISERROR('This user already owns this branch and does not need a staff assignment.', 16, 1);
        RETURN;
    END
    INSERT INTO food.restaurant_staff (user_id, branch_id)
    VALUES (@user_id, @branch_id);
END
GO

CREATE OR ALTER PROCEDURE food.sp_add_to_cart
    @user_id INT,
    @branch_id INT,
    @menu_item_id INT,
    @quantity INT
AS
BEGIN
    SET NOCOUNT ON;
    IF @quantity <= 0
    BEGIN
        RAISERROR('Quantity must be positive.', 16, 1);
        RETURN;
    END
    IF NOT EXISTS (
        SELECT 1 FROM food.menu_items
        WHERE menu_item_id = @menu_item_id
          AND branch_id = @branch_id
          AND availability_status = 1
    )
    BEGIN
        RAISERROR('Menu item is not available at this branch.', 16, 1);
        RETURN;
    END
    IF EXISTS (
        SELECT 1 FROM food.cart_items
        WHERE user_id = @user_id AND branch_id <> @branch_id
    )
    BEGIN
        RAISERROR('Cannot add items from different branches simultaneously.', 16, 1);
        RETURN;
    END
    IF EXISTS (
        SELECT 1 FROM food.cart_items
        WHERE user_id = @user_id AND branch_id = @branch_id AND menu_item_id = @menu_item_id
    )
    BEGIN
        UPDATE food.cart_items
        SET quantity = quantity + @quantity
        WHERE user_id = @user_id AND branch_id = @branch_id AND menu_item_id = @menu_item_id;
    END
    ELSE
    BEGIN
        INSERT INTO food.cart_items (user_id, branch_id, menu_item_id, quantity)
        VALUES (@user_id, @branch_id, @menu_item_id, @quantity);
    END
END
GO

CREATE OR ALTER PROCEDURE food.sp_write_log
    @actor_id INT = NULL,
    @operation_type VARCHAR(10),
    @target_table VARCHAR(50),
    @target_id VARCHAR(50),
    @old_value NVARCHAR(MAX) = NULL,
    @new_value NVARCHAR(MAX) = NULL,
    @description VARCHAR(500) = NULL,
    @branch_id INT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO food.food_logs
        (actor_id, operation_type, schema_name, target_table, target_id,
         old_value, new_value, log_timestamp, description, branch_id)
    VALUES
        (@actor_id, @operation_type, 'food', @target_table, @target_id,
         @old_value, @new_value, SYSDATETIME(), @description, @branch_id);
END
GO
