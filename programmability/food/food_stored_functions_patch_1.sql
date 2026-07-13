USE mini_snapp;
GO

CREATE FUNCTION food.fn_calculate_order_total(@order_id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @total DECIMAL(12,2);
    SELECT @total = SUM(quantity * current_price)
    FROM food.order_items
    WHERE order_id = @order_id;
    RETURN ISNULL(@total, 0);
END

GO


CREATE FUNCTION food.fn_can_cancel_order(
    @order_id INT,
    @actor_type VARCHAR(10)
)
RETURNS BIT
AS
BEGIN
    DECLARE @status VARCHAR(20);
    SELECT @status = status FROM food.food_orders WHERE order_id = @order_id;
    IF @status IN ('delivered','cancelled','disputed','picked_up')
        RETURN 0;
    IF @actor_type = 'user' AND @status IN ('pending','confirmed')
        RETURN 1;
    IF @actor_type = 'restaurant' AND @status IN ('pending','confirmed','preparing')
        RETURN 1;
    RETURN 0;
END

GO

