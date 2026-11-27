USE mini_snapp;
GO

CREATE OR ALTER TRIGGER food.trg_food_orders_timestamp_autofill
ON food.food_orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL() > 1 RETURN;
    IF NOT UPDATE(status) RETURN;

    UPDATE fo
    SET confirmed_at = CASE WHEN i.status = 'confirmed' AND fo.confirmed_at IS NULL THEN SYSDATETIME() ELSE fo.confirmed_at END,
        cooking_completed_at = CASE WHEN i.status = 'picked_up' AND fo.cooking_completed_at IS NULL THEN SYSDATETIME() ELSE fo.cooking_completed_at END,
        handed_to_courier_at = CASE WHEN i.status = 'picked_up' AND fo.handed_to_courier_at IS NULL THEN SYSDATETIME() ELSE fo.handed_to_courier_at END,
        delivered_at = CASE WHEN i.status = 'delivered' AND fo.delivered_at IS NULL THEN SYSDATETIME() ELSE fo.delivered_at END
    FROM food.food_orders fo
    JOIN inserted i ON i.order_id = fo.order_id;
END
GO

CREATE OR ALTER TRIGGER food.trg_menu_discounts_validate
ON food.menu_discounts
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted i WHERE i.percentage IS NULL AND i.amount IS NULL)
    BEGIN
        RAISERROR('A discount percentage or amount must be specified.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM inserted i WHERE i.percentage IS NOT NULL AND (i.percentage <= 0 OR i.percentage > 100))
    BEGIN
        RAISERROR('Discount percentage out of range.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN food.menu_discounts md
            ON md.menu_item_id = i.menu_item_id
           AND md.menu_discount_id <> i.menu_discount_id
           AND md.is_active = 1
        WHERE i.is_active = 1
          AND i.start_at < md.end_at
          AND i.end_at > md.start_at
    )
    BEGIN
        RAISERROR('Menu item already has an overlapping active discount period.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

CREATE OR ALTER TRIGGER food.trg_branches_after_insert_create_wallet
ON food.branches
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO food.branch_wallets (branch_id, balance)
    SELECT branch_id, 0
    FROM inserted;
END
GO

CREATE OR ALTER TRIGGER food.trg_cart_items_validate
ON food.cart_items
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN food.menu_items mi ON mi.menu_item_id = i.menu_item_id
        WHERE mi.branch_id <> i.branch_id
    )
    BEGIN
        RAISERROR('Specified branch does not have this menu item.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN food.menu_items mi ON mi.menu_item_id = i.menu_item_id
        WHERE mi.availability_status = 0
    )
    BEGIN
        RAISERROR('Menu item is currently unavailable.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

CREATE OR ALTER TRIGGER food.trg_order_purchase
ON food.order_items
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @order_id INT;
    DECLARE cur_orders CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT order_id FROM inserted;

    OPEN cur_orders;
    FETCH NEXT FROM cur_orders INTO @order_id;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @customer_id INT, @branch_id INT, @delivery_fee DECIMAL(10,2),
                @allocated_discount DECIMAL(10,2), @is_takeout BIT, @delivery_address_id INT,
                @order_status VARCHAR(20);
        DECLARE @target_id_str VARCHAR(50);

        SELECT
            @customer_id = customer_id,
            @branch_id = branch_id,
            @delivery_fee = delivery_fee,
            @allocated_discount = allocated_discount,
            @is_takeout = is_takeout,
            @delivery_address_id = delivery_address_id,
            @order_status = status
        FROM food.food_orders
        WHERE order_id = @order_id;

        IF @order_status = 'cancelled'
        BEGIN
            UPDATE food.food_orders SET final_price = 0 WHERE order_id = @order_id;
            FETCH NEXT FROM cur_orders INTO @order_id;
            CONTINUE;
        END

        DECLARE @food_subtotal DECIMAL(10,2) = food.fn_calculate_order_total(@order_id);
        DECLARE @true_total DECIMAL(10,2) = @food_subtotal + @delivery_fee - ISNULL(@allocated_discount, 0);
        IF @true_total < 0 SET @true_total = 0;

        DECLARE @already_charged DECIMAL(10,2);
        SELECT @already_charged = ISNULL(SUM(t.amount), 0)
        FROM food.order_payments op
        JOIN core.transactions t ON t.transaction_id = op.transaction_id
        WHERE op.order_id = @order_id
          AND t.transaction_status = 'completed';

        DECLARE @is_first_charge BIT = CASE WHEN @already_charged = 0 THEN 1 ELSE 0 END;
        DECLARE @delta DECIMAL(10,2) = @true_total - @already_charged;

        UPDATE food.food_orders SET final_price = @true_total WHERE order_id = @order_id;

        IF @delta > 0
        BEGIN
            UPDATE core.user_wallets
            SET balance = balance - @delta
            WHERE user_id = @customer_id
              AND balance >= @delta;

            IF @@ROWCOUNT = 0
            BEGIN
                CLOSE cur_orders;
                DEALLOCATE cur_orders;
                RAISERROR('Insufficient wallet balance for food order.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END

            INSERT INTO core.transactions
                (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
            VALUES
                (@customer_id, 'order_payment', 'completed', @delta, 'wallet', NULL, SYSDATETIME());

            DECLARE @txn_id INT = SCOPE_IDENTITY();

            INSERT INTO food.order_payments (order_id, transaction_id)
            VALUES (@order_id, @txn_id);

            DECLARE @commission_rate DECIMAL(5,4);
            SELECT @commission_rate = br.commission_rate
            FROM food.branches b
            JOIN food.brands br ON br.brand_id = b.brand_id
            WHERE b.branch_id = @branch_id;

            IF @commission_rate IS NULL
                SELECT @commission_rate = app_share / 100.0
                FROM core.fn_get_active_commission_rate('food', NULL);

            DECLARE @delta_food_portion DECIMAL(10,2) = @delta - CASE WHEN @is_first_charge = 1 THEN @delivery_fee - ISNULL(@allocated_discount, 0) ELSE 0 END;
            IF @delta_food_portion < 0 SET @delta_food_portion = 0;

            DECLARE @restaurant_payout DECIMAL(10,2) = ROUND(@delta_food_portion * (1 - ISNULL(@commission_rate, 0)), 2);
            DECLARE @app_payout DECIMAL(10,2) = @delta_food_portion - @restaurant_payout;

            UPDATE food.branch_wallets
            SET balance = balance + @restaurant_payout
            WHERE branch_id = @branch_id;

            IF NOT EXISTS (SELECT 1 FROM core.app_wallets)
                INSERT INTO core.app_wallets (total_balance) VALUES (0);

            UPDATE TOP (1) core.app_wallets
            SET total_balance = total_balance + @app_payout;

            EXEC food.sp_clear_cart @user_id = @customer_id, @branch_id = @branch_id;

            SET @target_id_str = CAST(@order_id AS VARCHAR(50));
            DECLARE @log_old_value VARCHAR(50) = CAST(@already_charged AS VARCHAR(50));
            DECLARE @log_new_value VARCHAR(50) = CAST(@true_total AS VARCHAR(50));
            DECLARE @log_desc VARCHAR(255) = CASE WHEN @is_first_charge = 1 THEN 'order purchased' ELSE 'order top up charge for additional items' END;

            EXEC food.sp_write_log
                @actor_id = @customer_id,
                @operation_type = 'insert',
                @target_table = 'order_payments',
                @target_id = @target_id_str,
                @old_value = @log_old_value,
                @new_value = @log_new_value,
                @description = @log_desc,
                @branch_id = @branch_id;
        END

        IF @is_first_charge = 1 AND @is_takeout = 0 AND @delivery_fee > 0 AND @order_status IN ('pending', 'confirmed')
        BEGIN
            DECLARE @origin_lat DECIMAL(10,8), @origin_lng DECIMAL(11,8);
            SELECT @origin_lat = latitude, @origin_lng = longitude
            FROM food.branches WHERE branch_id = @branch_id;

            DECLARE @dest_lat DECIMAL(10,8), @dest_lng DECIMAL(11,8);
            SELECT @dest_lat = latitude, @dest_lng = longitude
            FROM core.addresses WHERE address_id = @delivery_address_id;

            DECLARE @new_offer_id INT;
            EXEC taxi.sp_create_ride_offer
                @passenger_id = @customer_id,
                @origin_latitude = @origin_lat,
                @origin_longitude = @origin_lng,
                @destination_latitude = @dest_lat,
                @destination_longitude = @dest_lng,
                @vehicle_type = 'motorcycle',
                @service_type = 'cargo',
                @new_offer_id = @new_offer_id OUTPUT;

            SET @target_id_str = CAST(@new_offer_id AS VARCHAR(50));
            EXEC food.sp_write_log
                @actor_id = @customer_id,
                @operation_type = 'insert',
                @target_table = 'ride_offers',
                @target_id = @target_id_str,
                @old_value = NULL,
                @new_value = NULL,
                @description = 'ride offer created',
                @branch_id = @branch_id;
        END

        FETCH NEXT FROM cur_orders INTO @order_id;
    END

    CLOSE cur_orders;
    DEALLOCATE cur_orders;
END
GO

CREATE OR ALTER TRIGGER food.trg_food_orders_status_validate
ON food.food_orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(status) RETURN;

    IF EXISTS (
        SELECT 1 FROM inserted i JOIN deleted d ON d.order_id = i.order_id
        WHERE i.status <> d.status AND d.status IN ('delivered','cancelled','disputed')
    )
    BEGIN
        RAISERROR('Terminal order status cannot be changed.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN deleted d ON d.order_id = i.order_id
        JOIN (VALUES ('pending',1),('confirmed',2),('preparing',3),('picked_up',4),('delivered',5)) AS old_rank(status_name, rank_value)
            ON old_rank.status_name = d.status
        JOIN (VALUES ('pending',1),('confirmed',2),('preparing',3),('picked_up',4),('delivered',5)) AS new_rank(status_name, rank_value)
            ON new_rank.status_name = i.status
        WHERE i.status <> d.status
          AND i.status NOT IN ('cancelled','disputed')
          AND new_rank.rank_value <> old_rank.rank_value + 1
    )
    BEGIN
        RAISERROR('Order status can only advance one stage at a time.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

CREATE OR ALTER TRIGGER food.trg_food_orders_audit
ON food.food_orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(status) RETURN;

    DECLARE @actor_id INT = TRY_CAST(SESSION_CONTEXT(N'current_user_id') AS INT);

    INSERT INTO food.food_logs
        (actor_id, operation_type, schema_name, target_table, target_id,
         old_value, new_value, log_timestamp, description, branch_id)
    SELECT
        @actor_id,
        'update',
        'food',
        'food_orders',
        CAST(i.order_id AS VARCHAR(50)),
        d.status,
        i.status,
        SYSDATETIME(),
        'automatic audit log for order status change',
        i.branch_id
    FROM inserted i
    JOIN deleted d ON d.order_id = i.order_id
    WHERE i.status <> d.status;
END
GO

CREATE OR ALTER TRIGGER food.trg_food_orders_after_insert
ON food.food_orders
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @actor_id INT = TRY_CAST(SESSION_CONTEXT(N'current_user_id') AS INT);

    INSERT INTO food.food_logs
        (actor_id, operation_type, schema_name, target_table, target_id,
         old_value, new_value, log_timestamp, description, branch_id)
    SELECT
        ISNULL(@actor_id, i.customer_id),
        'insert',
        'food',
        'food_orders',
        CAST(i.order_id AS VARCHAR(50)),
        NULL,
        (SELECT i.status, i.is_takeout FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        SYSDATETIME(),
        'new order placed',
        i.branch_id
    FROM inserted i;
END
GO

CREATE OR ALTER TRIGGER food.trg_branches_audit
ON food.branches
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @actor_id INT = TRY_CAST(SESSION_CONTEXT(N'current_user_id') AS INT);

    INSERT INTO food.food_logs
        (actor_id, operation_type, schema_name, target_table, target_id,
         old_value, new_value, log_timestamp, description, branch_id)
    SELECT
        @actor_id,
        'update',
        'food',
        'branches',
        CAST(i.branch_id AS VARCHAR(50)),
        (SELECT d.is_active, d.rating FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        (SELECT i.is_active, i.rating FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        SYSDATETIME(),
        'automatic audit log for branch update',
        i.branch_id
    FROM inserted i
    JOIN deleted d ON d.branch_id = i.branch_id
    WHERE i.is_active <> d.is_active OR i.rating <> d.rating;
END
GO
