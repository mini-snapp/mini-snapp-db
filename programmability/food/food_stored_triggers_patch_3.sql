USE mini_snapp;
GO

CREATE TRIGGER food.trg_order_purchase
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
        IF NOT EXISTS (SELECT 1 FROM food.order_payments WHERE order_id = @order_id)
        BEGIN
            DECLARE @customer_id INT, @branch_id INT, @delivery_fee DECIMAL(10,2),
                    @allocated_discount DECIMAL(10,2), @is_takeout BIT, @delivery_address_id INT;
            DECLARE @target_id_str VARCHAR(50);
            SELECT
                @customer_id = customer_id,
                @branch_id = branch_id,
                @delivery_fee = delivery_fee,
                @allocated_discount = allocated_discount,
                @is_takeout = is_takeout,
                @delivery_address_id = delivery_address_id
            FROM food.food_orders
            WHERE order_id = @order_id;
            DECLARE @food_subtotal DECIMAL(12,2) = food.fn_calculate_order_total(@order_id);
            DECLARE @final_price DECIMAL(10,2) = @food_subtotal + @delivery_fee - ISNULL(@allocated_discount, 0);
            UPDATE food.food_orders SET final_price = @final_price WHERE order_id = @order_id;
            UPDATE core.user_wallets SET balance = balance - @final_price WHERE user_id = @customer_id; 
            INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
            VALUES (@customer_id, 'order_payment', 'completed', @final_price, 'wallet', NULL, SYSDATETIME());  
            DECLARE @txn_id INT = SCOPE_IDENTITY(); 
            INSERT INTO food.order_payments (order_id, transaction_id)
            VALUES (@order_id, @txn_id);
            DECLARE @commission_rate DECIMAL(5,4);
            SELECT @commission_rate = br.commission_rate
            FROM food.branches b
            JOIN food.brands br ON br.brand_id = b.brand_id
            WHERE b.branch_id = @branch_id;
            
            DECLARE @restaurant_payout DECIMAL(12,2) = @food_subtotal * (1 - ISNULL(@commission_rate, 0));
            UPDATE food.branch_wallets SET balance = balance + @restaurant_payout WHERE branch_id = @branch_id;
            EXEC food.sp_clear_cart @user_id = @customer_id, @branch_id = @branch_id;
            SET @target_id_str = CAST(@order_id AS VARCHAR(50));
            EXEC food.sp_write_log
                @actor_id = @customer_id,
                @operation_type = 'insert',
                @target_table = 'order_payments',
                @target_id = @target_id_str,  
                @old_value = NULL,
                @new_value = NULL,
                @description = 'order purchased',
                @branch_id = @branch_id;
            IF @is_takeout = 0 AND @delivery_fee > 0
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
        END
        FETCH NEXT FROM cur_orders INTO @order_id;
    END
    CLOSE cur_orders;
    DEALLOCATE cur_orders;
END

GO