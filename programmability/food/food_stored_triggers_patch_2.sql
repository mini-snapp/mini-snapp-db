USE mini_snapp;
GO

IF OBJECT_ID('food.trg_food_orders_status_validate', 'TR') IS NOT NULL
    DROP TRIGGER food.trg_food_orders_status_validate;
GO

CREATE TRIGGER food.trg_food_orders_status_validate
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
        RAISERROR('this order status cannot change', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    IF EXISTS (
        SELECT 1 FROM inserted i JOIN deleted d ON d.order_id = i.order_id
        JOIN (VALUES ('pending',1),('confirmed',2),('preparing',3),('picked_up',4),('delivered',5)) AS old_rank(status_name, rank_value) ON old_rank.status_name = d.status
        JOIN (VALUES ('pending',1),('confirmed',2),('preparing',3),('picked_up',4),('delivered',5)) AS new_rank(status_name, rank_value) ON new_rank.status_name = i.status
        WHERE i.status <> d.status AND i.status NOT IN ('cancelled','disputed')
          AND new_rank.rank_value <> old_rank.rank_value + 1
    )
    BEGIN
        RAISERROR('order status can only advance one stage at a time', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END

GO

IF OBJECT_ID('food.trg_food_orders_audit', 'TR') IS NOT NULL
    DROP TRIGGER food.trg_food_orders_audit;
GO

CREATE TRIGGER food.trg_food_orders_audit
ON food.food_orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(status) RETURN;
    DECLARE @actor_id INT = TRY_CAST(SESSION_CONTEXT(N'current_user_id') AS INT);
    DECLARE @order_id INT, @branch_id INT, @old_status VARCHAR(20), @new_status VARCHAR(20);
    SELECT TOP 1
        @order_id = i.order_id, @branch_id = i.branch_id,
        @old_status = d.status, @new_status = i.status
    FROM inserted i JOIN deleted d ON d.order_id = i.order_id
    WHERE i.status <> d.status;
    IF @order_id IS NOT NULL
        EXEC food.sp_write_log
            @actor_id = @actor_id, @operation_type = 'update', @target_table = 'food_orders',
            @target_id = @order_id, @old_value = @old_status, @new_value = @new_status,
            @description = 'automatic audit log for order status change', @branch_id = @branch_id;
END

GO


CREATE TRIGGER food.trg_food_orders_after_insert
ON food.food_orders
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @actor_id INT = TRY_CAST(SESSION_CONTEXT(N'current_user_id') AS INT);
    INSERT INTO food.food_logs (actor_id, operation_type, schema_name, target_table, target_id, old_value, new_value, log_timestamp, description, branch_id)
    SELECT
        ISNULL(@actor_id, i.customer_id), 'insert', 'food', 'food_orders', CAST(i.order_id AS VARCHAR(50)),
        NULL, (SELECT i.status, i.is_takeout FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        SYSDATETIME(), 'New order placed', i.branch_id
    FROM inserted i;
END

GO

IF OBJECT_ID('food.trg_food_orders_delivered_charge', 'TR') IS NOT NULL
    DROP TRIGGER food.trg_food_orders_delivered_charge;
GO


IF OBJECT_ID('food.trg_branches_audit', 'TR') IS NOT NULL
    DROP TRIGGER food.trg_branches_audit;
GO

CREATE TRIGGER food.trg_branches_audit
ON food.branches
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @actor_id INT = TRY_CAST(SESSION_CONTEXT(N'current_user_id') AS INT);
    DECLARE @branch_id INT, @old_json NVARCHAR(MAX), @new_json NVARCHAR(MAX);
    SELECT TOP 1
        @branch_id = i.branch_id,
        @old_json = (SELECT d.is_active, d.rating FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        @new_json = (SELECT i.is_active, i.rating FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM inserted i JOIN deleted d ON d.branch_id = i.branch_id
    WHERE i.is_active <> d.is_active OR i.rating <> d.rating;
    IF @branch_id IS NOT NULL
        EXEC food.sp_write_log
            @actor_id = @actor_id, @operation_type = 'update', @target_table = 'branches',
            @target_id = @branch_id, @old_value = @old_json, @new_value = @new_json,
            @description = 'Automatic audit log for branch update', @branch_id = @branch_id;
END

GO