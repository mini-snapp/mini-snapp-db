USE mini_snapp;
GO


CREATE PROCEDURE food.sp_add_to_cart
    @user_id INT,
    @branch_id INT,
    @menu_item_id INT,
    @quantity INT
AS
BEGIN
    SET NOCOUNT ON;
    IF @quantity <= 0
    BEGIN
        RAISERROR('negatie quantity', 16, 1);
        RETURN;
    END
    IF NOT EXISTS (
        SELECT 1 FROM food.menu_items
        WHERE menu_item_id = @menu_item_id
          AND branch_id = @branch_id
          AND availability_status = 1
    )
    BEGIN
        RAISERROR('menu item is not availabl', 16, 1);
        RETURN;
    END
    IF EXISTS (
        SELECT 1 FROM food.cart_items
        WHERE user_id = @user_id AND branch_id <> @branch_id
    )
    BEGIN
        RAISERROR('Your cant buy from diffrent branches simultasionsly', 16, 1);
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