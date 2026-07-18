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

CREATE FUNCTION food.fn_haversine_km(
    @lat1 DECIMAL(9,6),
    @lng1 DECIMAL(9,6),
    @lat2 DECIMAL(9,6),
    @lng2 DECIMAL(9,6)
)
RETURNS DECIMAL(9,3)
AS
BEGIN
    DECLARE @r FLOAT = 6371.0;
    DECLARE @dLat FLOAT = RADIANS(CAST(@lat2 AS FLOAT) - CAST(@lat1 AS FLOAT));
    DECLARE @dLng FLOAT = RADIANS(CAST(@lng2 AS FLOAT) - CAST(@lng1 AS FLOAT));
    DECLARE @a FLOAT = SIN(@dLat / 2) * SIN(@dLat / 2) + COS(RADIANS(CAST(@lat1 AS FLOAT))) * COS(RADIANS(CAST(@lat2 AS FLOAT))) * SIN(@dLng / 2) * SIN(@dLng / 2);
    DECLARE @c FLOAT = 2 * ATN2(SQRT(@a), SQRT(1 - @a));
    RETURN CAST(@r * @c AS DECIMAL(9,3));
END

GO

CREATE FUNCTION food.fn_branches_within_distance(
    @user_lat DECIMAL(9,6),
    @user_lng DECIMAL(9,6),
    @radius_km DECIMAL(9,3)
)
RETURNS TABLE
AS
RETURN(
    SELECT
        b.branch_id,
        b.brand_id,
        b.city,
        b.food_type,
        b.max_delivery_distance,
        food.fn_haversine_km(@user_lat, @user_lng, b.latitude, b.longitude) AS distance_km
    FROM food.branches b
    WHERE b.is_active = 1 AND food.fn_haversine_km(@user_lat, @user_lng, b.latitude, b.longitude) <= @radius_km AND food.fn_haversine_km(@user_lat, @user_lng, b.latitude, b.longitude) <= b.max_delivery_distance
)

GO

CREATE FUNCTION food.fn_is_branch_open(
    @branch_id INT,
    @check_datetime DATETIME2
)
RETURNS BIT
AS
BEGIN
    DECLARE @result BIT = 0;
    DECLARE @day INT = DATEPART(WEEKDAY, @check_datetime) - 1;
    DECLARE @time TIME = CAST(@check_datetime AS TIME);

    IF EXISTS (
        SELECT 1 FROM food.work_schedules ws
        WHERE ws.branch_id = @branch_id
          AND ws.day_of_week = @day
          AND ws.is_closed = 0
          AND @time BETWEEN ws.start_time AND ws.end_time
    )
        SET @result = 1;

    RETURN @result;
END

GO

CREATE FUNCTION food.fn_get_effective_menu_price(
    @menu_item_id INT
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @price DECIMAL(10,2);
    DECLARE @effective_price DECIMAL(10,2);
    SELECT @price = price FROM food.menu_items WHERE menu_item_id = @menu_item_id;
    SELECT TOP 1 @effective_price =
        @price - ISNULL(md.amount, 0) - (@price * ISNULL(md.percentage, 0) / 100)
    FROM food.menu_discounts md
    WHERE md.menu_item_id = @menu_item_id AND md.is_active = 1  AND SYSDATETIME() BETWEEN md.start_at AND md.end_at
    ORDER BY md.menu_discount_id DESC;

    RETURN ISNULL(@effective_price, @price);

END

GO

CREATE FUNCTION food.fn_calculate_cart_total(
    @user_id INT,
    @branch_id INT
)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @total DECIMAL(12,2);
    SELECT @total = SUM(ci.quantity * food.fn_get_effective_menu_price(ci.menu_item_id))
    FROM food.cart_items ci
    WHERE ci.user_id = @user_id AND ci.branch_id = @branch_id;

    RETURN ISNULL(@total, 0);
END

GO
