USE mini_snapp;
GO

CREATE TRIGGER food.trg_menu_discounts_validate
ON food.menu_discounts
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted i WHERE i.percentage IS NULL AND i.amount IS NULL)
    BEGIN
        RAISERROR('a discount must be specified', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM inserted i WHERE i.percentage IS NOT NULL AND (i.percentage < 0 OR i.percentage > 100))
    BEGIN
        RAISERROR('discount percentage out of range', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN food.menu_discounts md ON md.menu_item_id = i.menu_item_id AND md.menu_discount_id <> i.menu_discount_id AND md.is_active = 1
        WHERE i.is_active = 1 AND i.start_at < md.end_at  AND i.end_at > md.start_at
    )
    BEGIN
        RAISERROR('menu item already has overlapping active discount period', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END

GO

CREATE TRIGGER food.trg_branches_after_insert_create_wallet
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

CREATE TRIGGER food.trg_cart_items_validate
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
        RAISERROR('specified branch doesnt have this item', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN food.menu_items mi ON mi.menu_item_id = i.menu_item_id
        WHERE mi.availability_status = 0
    )
    BEGIN
        RAISERROR('menu item is currently unavailable', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END

GO

CREATE TRIGGER food.trg_branches_audit
ON food.branches
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @actor_id INT = TRY_CAST(SESSION_CONTEXT(N'current_user_id') AS INT);

    INSERT INTO food.food_logs (actor_id, operation_type, schema_name, target_table, target_id, old_value, new_value, log_timestamp, description, branch_id)
    SELECT
        @actor_id,
        'UPDATE',
        'food',
        'branches',
        CAST(i.branch_id AS VARCHAR(50)),
        (SELECT d.is_active, d.rating FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        (SELECT i.is_active, i.rating FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        SYSDATETIME(),
        'Automatic audit log for branch update',
        i.branch_id
    FROM inserted i
    JOIN deleted d ON d.branch_id = i.branch_id
    WHERE i.is_active <> d.is_active OR i.rating <> d.rating;
END

GO