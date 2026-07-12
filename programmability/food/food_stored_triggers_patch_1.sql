USE mini_snapp;
GO

CREATE TRIGGER food.trg_food_orders_status_validate
ON food.food_orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(status) RETURN;
    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN deleted d ON d.order_id = i.order_id
        WHERE i.status <> d.status AND d.status IN ('delivered','cancelled','disputed')
    )
    BEGIN
        RAISERROR('order is in terminal state and its status cannot change', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN deleted d ON d.order_id = i.order_id
        JOIN (VALUES ('pending',1),('confirmed',2),('preparing',3),('picked_up',4),('delivered',5)) AS old_rank(status_name, rank_value)
            ON old_rank.status_name = d.status JOIN (VALUES ('pending',1),('confirmed',2),('preparing',3),('picked_up',4),('delivered',5)) AS new_rank(status_name, rank_value)
            ON new_rank.status_name = i.status
        WHERE i.status <> d.status
          AND i.status NOT IN ('cancelled','disputed')  AND new_rank.rank_value <> old_rank.rank_value + 1
    )
    BEGIN
        RAISERROR('order status can only advance one stage at  time', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END

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

CREATE TRIGGER food.trg_food_orders_audit
ON food.food_orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(status) RETURN;
    DECLARE @actor_id INT = TRY_CAST(SESSION_CONTEXT(N'current_user_id') AS INT);
    INSERT INTO food.food_logs (actor_id, operation_type, schema_name, target_table, target_id, old_value, new_value, log_timestamp, description, branch_id)
    SELECT
        @actor_id, 'UPDATE', 'food', 'food_orders', CAST(i.order_id AS VARCHAR(50)),
        (SELECT d.status FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        (SELECT i.status FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        SYSDATETIME(), 'Automatic audit log for order status change', i.branch_id
    FROM inserted i JOIN deleted d ON d.order_id = i.order_id
    WHERE i.status <> d.status;
END

GO
