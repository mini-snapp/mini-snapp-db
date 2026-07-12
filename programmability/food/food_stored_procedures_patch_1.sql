USE mini_snapp;
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
        RAISERROR('order cannot be cancelled', 16, 1);
        RETURN;
    END
    UPDATE food.food_orders SET status = 'cancelled', rejection_reason = @reason WHERE order_id = @order_id;
END

GO