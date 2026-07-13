USE mini_snapp;
GO

CREATE TRIGGER food.trg_food_orders_timestamp_autofill
ON food.food_orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(status) RETURN;
    UPDATE fo
    SET confirmed_at = CASE WHEN i.status = 'confirmed' AND fo.confirmed_at IS NULL THEN SYSDATETIME() ELSE fo.confirmed_at END,
        cooking_completed_at = CASE WHEN i.status = 'picked_up' AND fo.cooking_completed_at IS NULL THEN SYSDATETIME() ELSE fo.cooking_completed_at END,
        handed_to_courier_at = CASE WHEN i.status = 'picked_up' AND fo.handed_to_courier_at IS NULL THEN SYSDATETIME() ELSE fo.handed_to_courier_at END,
        delivered_at = CASE WHEN i.status = 'delivered' AND fo.delivered_at IS NULL THEN SYSDATETIME() ELSE fo.delivered_at END
    FROM food.food_orders fo JOIN inserted i ON i.order_id = fo.order_id;
END

GO

