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

CREATE FUNCTION taxi.fn_calculate_ride_fare(
    @distance_km DECIMAL(9,3),
    @duration_min INT,
    @vehicle_type VARCHAR(20),
    @service_type VARCHAR(20)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @base_fare DECIMAL(10,2), @per_km DECIMAL(10,2), @per_min DECIMAL(10,2);
    DECLARE @fare DECIMAL(10,2);
    SELECT TOP 1
        @base_fare = base_fare,
        @per_km = price_per_km,
        @per_min = price_per_minute
    FROM taxi.pricing_parameters
    WHERE vehicle_type = @vehicle_type AND service_type = @service_type 
    AND effective_from <= SYSDATETIME()  AND (effective_to IS NULL OR effective_to > SYSDATETIME())
    ORDER BY effective_from DESC;
    SET @fare = @base_fare + (@per_km * @distance_km) + (@per_min * @duration_min);
    RETURN @fare;
END

GO

CREATE FUNCTION taxi.fn_find_nearest_available_driver(
    @pickup_lat DECIMAL(10,8),
    @pickup_lng DECIMAL(11,8),
    @vehicle_type VARCHAR(20),
    @radius_km DECIMAL(9,3)
)
RETURNS INT
AS
BEGIN
    DECLARE @driver_id INT;
    SELECT TOP 1 @driver_id = d.driver_id
    FROM taxi.drivers d JOIN taxi.driver_locations dl ON dl.driver_id = d.driver_id
    JOIN taxi.vehicles v ON v.owner_id = d.driver_id AND v.is_active_now = 1
    WHERE d.driver_status = 'available' AND v.vehicle_type = @vehicle_type
      AND food.fn_haversine_km(@pickup_lat, @pickup_lng, dl.latitude, dl.longitude) <= @radius_km
    ORDER BY food.fn_haversine_km(@pickup_lat, @pickup_lng, dl.latitude, dl.longitude) ASC;
    RETURN @driver_id;
END

GO