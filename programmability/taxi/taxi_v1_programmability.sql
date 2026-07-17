USE mini_snapp;
GO


-- 1. Helper Stored Procedures

CREATE OR ALTER PROCEDURE taxi.sp_write_log
    @actor_id INT = NULL,
    @operation_type VARCHAR(10),
    @schema_name VARCHAR(10) = 'taxi',
    @target_table VARCHAR(50),
    @target_id VARCHAR(50),
    @old_value NVARCHAR(MAX) = NULL,
    @new_value NVARCHAR(MAX) = NULL,
    @description NVARCHAR(MAX) = NULL,
    @driver_id INT = NULL,
    @ride_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO taxi.taxi_logs
        (actor_id, operation_type, schema_name, target_table, target_id,
             old_value, new_value, [description], driver_id, ride_id)
    VALUES
        (@actor_id, @operation_type, @schema_name, @target_table, 
            @target_id, @old_value, @new_value, @description, @driver_id, @ride_id);
END
GO

CREATE OR ALTER PROCEDURE taxi.sp_register_driver
    @user_id INT,
    @national_id VARCHAR(15),
    @date_of_birth DATE,
    @gender VARCHAR(15) = NULL,
    @new_driver_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM taxi.drivers WHERE user_id = @user_id)
    BEGIN
        RAISERROR('User is already registered as a driver.', 16, 1);
        RETURN;
    END

    DECLARE @driver_role_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'driver');

    BEGIN TRY
        BEGIN TRANSACTION;
        
        INSERT INTO taxi.drivers (user_id, national_id, date_of_birth, gender)
        VALUES (@user_id, @national_id, @date_of_birth, @gender);
        
        SET @new_driver_id = SCOPE_IDENTITY();
        
        UPDATE core.users
        SET role_id = @driver_role_id
        WHERE user_id = @user_id;

        INSERT INTO taxi.driver_wallets (driver_id, balance)
        VALUES (@new_driver_id, 0);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        ;THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE taxi.sp_register_vehicle
    @owner_id INT,
    @vehicle_type VARCHAR(20),
    @license_plate VARCHAR(20),
    @color VARCHAR(20),
    @model_name VARCHAR(20),
    @new_vehicle_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO taxi.vehicles
        (owner_id, vehicle_type, license_plate, color, model_name, is_active_now)
    VALUES
        (@owner_id, @vehicle_type, @license_plate, @color, @model_name, 1);
    
    SET @new_vehicle_id = SCOPE_IDENTITY();
END
GO


-- 2. Pricing and Search Functions


CREATE OR ALTER FUNCTION taxi.fn_get_active_pricing_parameter
(
    @vehicle_type VARCHAR(20),
    @service_type VARCHAR(20),
    @check_date DATETIME = NULL
)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP 1 *
    FROM taxi.pricing_parameters
    WHERE vehicle_type = @vehicle_type
        AND service_type = @service_type
        AND (effective_to IS NULL OR effective_to > ISNULL(@check_date, GETDATE()))
        AND effective_from <= ISNULL(@check_date, GETDATE())
    ORDER BY effective_from DESC
);
GO

CREATE OR ALTER FUNCTION taxi.fn_calculate_ride_price
(
    @vehicle_type VARCHAR(20),
    @service_type VARCHAR(20),
    @distance_km DECIMAL(10,2),
    @duration_minutes INT = NULL,
    @check_date DATETIME = NULL
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @base_fare DECIMAL(10,2);
    DECLARE @price_per_km DECIMAL(10,2);
    DECLARE @price_per_minute DECIMAL(10,2);
    DECLARE @price DECIMAL(10,2);
 
    SELECT @base_fare = base_fare, @price_per_km = price_per_km, 
        @price_per_minute = price_per_minute
    FROM taxi.fn_get_active_pricing_parameter(@vehicle_type, @service_type, @check_date);
 
    IF @base_fare IS NULL 
        RETURN NULL;

    SET @price = @base_fare +
        (@price_per_km * @distance_km) +
        (@price_per_minute * ISNULL(@duration_minutes, 0));

    RETURN @price;
END
GO

CREATE OR ALTER FUNCTION taxi.fn_vehicle_supports_service
(
    @vehicle_id INT,
    @service_type VARCHAR(20)
)
RETURNS BIT
AS
BEGIN
    DECLARE @result BIT = 0;
    IF EXISTS (
        SELECT 1
        FROM taxi.vehicles v
        JOIN taxi.vehicle_type_services vts 
            ON vts.vehicle_type = v.vehicle_type
        WHERE v.vehicle_id = @vehicle_id 
            AND vts.service_type = @service_type
    ) 
        SET @result = 1;
    
    RETURN @result;
END
GO

CREATE OR ALTER FUNCTION taxi.fn_find_nearest_available_drivers
(
    @origin_latitude DECIMAL(10,8),
    @origin_longitude DECIMAL(11,8),
    @vehicle_type VARCHAR(20),
    @service_type VARCHAR(20),
    @max_results INT = 5
)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP (@max_results)
        d.driver_id, v.vehicle_id, dl.latitude, dl.longitude,
        core.fn_calculate_distance_km(@origin_latitude, 
            @origin_longitude, dl.latitude, dl.longitude) AS distance_km
    FROM taxi.drivers d 
    JOIN taxi.driver_locations dl ON dl.driver_id = d.driver_id
    JOIN taxi.vehicles v ON v.owner_id = d.driver_id 
    JOIN taxi.vehicle_type_services vts ON vts.vehicle_type = v.vehicle_type
    WHERE d.driver_status = 'available'
      AND v.is_active_now = 1
      AND v.vehicle_type = @vehicle_type
      AND vts.service_type = @service_type
    ORDER BY distance_km ASC 
);
GO

-- 3. Ride State Machine Procedures


CREATE OR ALTER PROCEDURE taxi.sp_create_ride_offer
    @passenger_id INT,
    @origin_latitude DECIMAL(10,8),
    @origin_longitude DECIMAL(11,8),
    @destination_latitude DECIMAL(10,8),
    @destination_longitude DECIMAL(11,8),
    @vehicle_type VARCHAR(20),
    @service_type VARCHAR(20),
    @candidate_count INT = 5,
    @offer_ttl_minutes INT = 3,
    @is_prepaid BIT = 0,
    @scheduled_start_time DATETIME = NULL,
    @new_offer_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 
        FROM taxi.vehicle_type_services 
        WHERE vehicle_type = @vehicle_type 
            AND service_type = @service_type
    )
    BEGIN
        RAISERROR('The requested vehicle type does not support the requested service type.', 16, 1);
        RETURN;
    END

    DECLARE @distance_km DECIMAL(10,2) = 
        core.fn_calculate_distance_km(@origin_latitude, @origin_longitude, 
            @destination_latitude, @destination_longitude);
            
    DECLARE @price DECIMAL(10,2) = 
        taxi.fn_calculate_ride_price(@vehicle_type, @service_type, 
            @distance_km, NULL, NULL);

    IF @price IS NULL
    BEGIN
        RAISERROR('No active pricing parameter found for this vehicle/service type.', 16, 1);
        RETURN;
    END
 
    BEGIN TRY
        BEGIN TRANSACTION;
 
        INSERT INTO taxi.ride_offers 
            (passenger_id, origin_latitude, origin_longitude, destination_latitude,
             destination_longitude, calculated_price, 
             vehicle_type, service_type, expires_at,
             is_prepaid, scheduled_start_time)
        VALUES 
            (@passenger_id, @origin_latitude, @origin_longitude, 
             @destination_latitude, @destination_longitude, @price,
             @vehicle_type, @service_type, DATEADD(MINUTE, @offer_ttl_minutes, GETDATE()),
             @is_prepaid, @scheduled_start_time);
 
        SET @new_offer_id = SCOPE_IDENTITY();
 
        INSERT INTO taxi.ride_offer_candidates 
            (offer_id, driver_id)
        SELECT @new_offer_id, driver_id
        FROM taxi.fn_find_nearest_available_drivers
            (@origin_latitude, @origin_longitude, @vehicle_type,
             @service_type, @candidate_count);
 
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 
        BEGIN
            ROLLBACK TRANSACTION;
            ;THROW;
        END
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE taxi.sp_respond_to_ride_offer
    @offer_id INT,
    @driver_id INT,
    @response VARCHAR(20),
    @new_ride_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @response NOT IN ('accepted','rejected')
    BEGIN
        RAISERROR('Response must be either accepted or rejected.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (
        SELECT 1 
        FROM taxi.ride_offer_candidates 
        WHERE offer_id = @offer_id 
            AND driver_id = @driver_id 
            AND response_status = 'pending'  
    )
    BEGIN
        RAISERROR('No pending candidate row found for this offer/driver.', 16, 1);
        RETURN;
    END
        
    BEGIN TRY
        BEGIN TRANSACTION;
 
        UPDATE taxi.ride_offer_candidates
        SET response_status = @response, 
            responded_at = GETDATE()
        WHERE offer_id = @offer_id 
            AND driver_id = @driver_id;
 
        IF @response = 'accepted'
        BEGIN
            DECLARE @passenger_id INT;
            DECLARE @origin_lat DECIMAL(10,8);
            DECLARE @origin_lng DECIMAL(11,8);
            DECLARE @dest_lat DECIMAL(10,8);
            DECLARE @dest_lng DECIMAL(11,8);
            DECLARE @price DECIMAL(10,2);
            DECLARE @vehicle_type VARCHAR(20);
            DECLARE @service_type VARCHAR(20);
            DECLARE @distance_km DECIMAL(10,2);
            DECLARE @vehicle_id INT;
            DECLARE @now DATETIME = GETDATE();
            DECLARE @expires_at DATETIME;
            DECLARE @requested_at DATETIME;
            
            DECLARE @is_prepaid BIT;
            DECLARE @scheduled_start_time DATETIME;
            DECLARE @initial_payment_status VARCHAR(20);
            DECLARE @initial_ride_status VARCHAR(20);
 
            SELECT 
                @passenger_id = passenger_id,
                @origin_lat = origin_latitude,
                @origin_lng = origin_longitude,
                @dest_lat = destination_latitude,
                @dest_lng = destination_longitude,
                @price = calculated_price,
                @vehicle_type = vehicle_type,
                @service_type = service_type,
                @requested_at = requested_at,
                @expires_at = expires_at,
                @is_prepaid = is_prepaid,
                @scheduled_start_time = scheduled_start_time
            FROM taxi.ride_offers 
            WHERE ride_offer_id = @offer_id;
 
            SELECT TOP 1 @vehicle_id = vehicle_id 
            FROM taxi.vehicles 
            WHERE owner_id = @driver_id 
                AND vehicle_type = @vehicle_type 
                AND is_active_now = 1;
 
            IF @vehicle_id IS NULL
            BEGIN
                RAISERROR('Driver has no active vehicle of the requested type.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF taxi.fn_vehicle_supports_service(@vehicle_id, @service_type) = 0
            BEGIN
                RAISERROR('Driver''s active vehicle does not support the requested service type.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @expires_at <= GETDATE()
            BEGIN
                RAISERROR('The offer has already expired!', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END
 
            SET @distance_km = core.fn_calculate_distance_km(@origin_lat, @origin_lng, @dest_lat, @dest_lng);
            
            SET @initial_payment_status = CASE WHEN @is_prepaid = 1 THEN 'paid' ELSE 'pending' END;
            
            SET @initial_ride_status = CASE 
                WHEN @scheduled_start_time > @now THEN 'scheduled' 
                ELSE 'to_origin' 
            END;
 
            INSERT INTO taxi.rides
                (passenger_id, driver_id, vehicle_id, origin_latitude,
                origin_longitude, destination_latitude, destination_longitude,
                estimated_distance, calculated_price, allocated_discount,
                service_type, requested_at, accepted_at, ride_status,
                ride_payment_status, scheduled_start_time)
            VALUES 
                (@passenger_id, @driver_id, @vehicle_id, @origin_lat,
                @origin_lng, @dest_lat, @dest_lng, @distance_km, @price,
                0, @service_type, @requested_at, @now, @initial_ride_status,
                @initial_payment_status, @scheduled_start_time);
 
            SET @new_ride_id = SCOPE_IDENTITY();
 
            UPDATE taxi.ride_offer_candidates 
            SET response_status = 'timeout',
                responded_at = GETDATE() 
            WHERE offer_id = @offer_id 
                AND driver_id <> @driver_id 
                AND response_status = 'pending';
    
            UPDATE taxi.drivers 
            SET driver_status = 'busy' 
            WHERE driver_id = @driver_id;
        END
 
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 
        BEGIN
            ROLLBACK TRANSACTION;
            ;THROW;
        END
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE taxi.sp_pay_for_ride
    @ride_id INT,
    @payment_method VARCHAR(15) = 'wallet'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @passenger_id INT;
    DECLARE @final_price DECIMAL(10,2);
    DECLARE @discount DECIMAL(10,2);
    DECLARE @payment_status VARCHAR(20);

    SELECT
        @passenger_id = passenger_id,
        @final_price = calculated_price,
        @discount = allocated_discount,
        @payment_status = ride_payment_status
    FROM taxi.rides
    WHERE ride_id = @ride_id;

    IF @passenger_id IS NULL
    BEGIN
        RAISERROR('Ride not found.', 16, 1);
        RETURN;
    END

    IF @payment_status = 'paid'
    BEGIN
        RAISERROR('Ride is already paid.', 16, 1);
        RETURN;
    END

    DECLARE @net_amount DECIMAL(10,2) = @final_price - ISNULL(@discount, 0);

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @transaction_id INT;

        INSERT INTO core.transactions
            (user_id, transaction_type, transaction_status, amount, payment_method)
        VALUES
            (@passenger_id, 'ride_payment', 'completed', @net_amount, @payment_method);

        SET @transaction_id = SCOPE_IDENTITY();

        INSERT INTO taxi.ride_payments
            (ride_id, ride_payment_transaction_id)
        VALUES
            (@ride_id, @transaction_id);

        IF @payment_method = 'wallet'
        BEGIN
            UPDATE core.user_wallets
            SET balance = balance - @net_amount
            WHERE user_id = @passenger_id;
        END

        UPDATE taxi.rides
        SET ride_payment_status = 'paid'
        WHERE ride_id = @ride_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
            ;THROW;
        END
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE taxi.sp_update_ride_status
    @ride_id INT,
    @new_status VARCHAR(20),
    @cancel_reason VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @current_status VARCHAR(20);
    
    SELECT @current_status = ride_status
    FROM taxi.rides 
    WHERE ride_id = @ride_id;

    IF @current_status IS NULL 
    BEGIN 
        RAISERROR('Ride not found.', 16, 1); 
        RETURN; 
    END
    
    IF @current_status IN ('completed', 'cancelled') 
    BEGIN 
        RAISERROR('Cannot transition from a terminal state.', 16, 1); 
        RETURN;
    END

    IF @new_status = 'to_origin' AND @current_status <> 'scheduled'
    BEGIN 
        RAISERROR('Invalid status transition to to_origin.', 16, 1); 
        RETURN; 
    END
    
    IF @new_status = 'to_destination' AND @current_status <> 'to_origin'
    BEGIN 
        RAISERROR('Invalid status transition to to_destination.', 16, 1); 
        RETURN; 
    END
    
    IF @new_status = 'completed' AND @current_status <> 'to_destination'
    BEGIN 
        RAISERROR('Invalid status transition to completed.', 16, 1); 
        RETURN; 
    END

    IF @new_status = 'to_origin'
    BEGIN
        UPDATE taxi.rides 
        SET ride_status = 'to_origin'
        WHERE ride_id = @ride_id;
    END
    ELSE IF @new_status = 'to_destination'
    BEGIN
        UPDATE taxi.rides 
        SET ride_status = 'to_destination',
            started_at = GETDATE()
        WHERE ride_id = @ride_id;
    END
    ELSE IF @new_status = 'completed'
    BEGIN
        UPDATE taxi.rides 
        SET ride_status = 'completed',
            completed_at = GETDATE()
        WHERE ride_id = @ride_id;
    END
    ELSE IF @new_status = 'cancelled'
    BEGIN
        UPDATE taxi.rides 
        SET ride_status = 'cancelled', 
            cancelled_at = GETDATE(), 
            cancel_reason = @cancel_reason 
        WHERE ride_id = @ride_id;
    END
END
GO

CREATE OR ALTER PROCEDURE taxi.sp_start_ride_to_origin
    @ride_id INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC taxi.sp_update_ride_status @ride_id, 'to_origin';
END
GO

CREATE OR ALTER PROCEDURE taxi.sp_start_ride_to_destination
    @ride_id INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC taxi.sp_update_ride_status @ride_id, 'to_destination';
END
GO

CREATE OR ALTER PROCEDURE taxi.sp_complete_ride
    @ride_id INT,
    @payment_method VARCHAR(15) = 'wallet'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @passenger_id INT;
    DECLARE @driver_id INT;
    DECLARE @final_price DECIMAL(10,2);
    DECLARE @discount DECIMAL(10,2);
    DECLARE @payment_status VARCHAR(20);
 
    SELECT 
        @passenger_id = passenger_id, 
        @driver_id = driver_id,
        @final_price = calculated_price, 
        @discount = allocated_discount,
        @payment_status = ride_payment_status
    FROM taxi.rides 
    WHERE ride_id = @ride_id;
 
    IF @passenger_id IS NULL 
    BEGIN 
        RAISERROR('Ride not found.', 16, 1); 
        RETURN; 
    END
 
    DECLARE @net_amount DECIMAL(10,2) = @final_price - ISNULL(@discount, 0);
    DECLARE @driver_share DECIMAL(5,2);
    DECLARE @app_share DECIMAL(5,2);
 
    SELECT 
        @driver_share = driver_share, 
        @app_share = app_share
    FROM core.fn_get_active_commission_rate('taxi', GETDATE());
 
    IF @driver_share IS NULL OR @app_share IS NULL
    BEGIN
        RAISERROR('No active commission rate found for taxi.', 16, 1);
        RETURN;
    END
 
    BEGIN TRY
        BEGIN TRANSACTION;


        IF @payment_status = 'pending'
        BEGIN
            EXEC taxi.sp_pay_for_ride @ride_id, @payment_method;
        END
 
        EXEC taxi.sp_update_ride_status @ride_id, 'completed';
 

        UPDATE taxi.driver_wallets 
        SET balance = balance + (@net_amount * @driver_share / 100)
        WHERE driver_id = @driver_id;


        UPDATE core.app_wallets
        SET total_balance = total_balance + (@net_amount * @app_share / 100);
        
    
        UPDATE taxi.drivers 
        SET driver_status = 'available'
        WHERE driver_id = @driver_id;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 
        BEGIN
            ROLLBACK TRANSACTION;
            ;THROW;
        END
    END CATCH
END

GO

CREATE OR ALTER PROCEDURE taxi.sp_cancel_ride
    @ride_id INT,
    @cancel_reason VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @driver_id INT;
    DECLARE @passenger_id INT;
    DECLARE @payment_status VARCHAR(20);
    DECLARE @final_price DECIMAL(10,2);
    DECLARE @discount DECIMAL(10,2);

    SELECT 
        @driver_id = driver_id,
        @passenger_id = passenger_id,
        @payment_status = ride_payment_status,
        @final_price = calculated_price,
        @discount = allocated_discount
    FROM taxi.rides 
    WHERE ride_id = @ride_id;

    BEGIN TRY
        BEGIN TRANSACTION;
        
        EXEC taxi.sp_update_ride_status @ride_id, 'cancelled', @cancel_reason;
        
        UPDATE taxi.drivers 
        SET driver_status = 'available' 
        WHERE driver_id = @driver_id;
        
        IF @payment_status = 'paid'
        BEGIN
            DECLARE @net_amount DECIMAL(10,2) = @final_price - ISNULL(@discount, 0);
            
            INSERT INTO core.transactions 
                (user_id, transaction_type, transaction_status, amount, payment_method)
            VALUES 
                (@passenger_id, 'refund', 'completed', @net_amount, 'wallet');
                
            UPDATE core.user_wallets 
            SET balance = balance + @net_amount 
            WHERE user_id = @passenger_id;
            
            UPDATE taxi.rides
            SET ride_payment_status = 'refunded'
            WHERE ride_id = @ride_id;
        END
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 
        BEGIN
            ROLLBACK TRANSACTION;
            ;THROW;
        END
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE taxi.sp_rate_ride
    @ride_id INT,
    @rater_role VARCHAR(15), 
    @rating INT,
    @comment NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @rating NOT BETWEEN 1 AND 5 
    BEGIN
        RAISERROR('Rating must be between 1 and 5.', 16, 1); 
        RETURN;
    END
    
    DECLARE @status VARCHAR(20);
    SELECT @status = ride_status 
    FROM taxi.rides 
    WHERE ride_id = @ride_id;
    
    IF @status IS NULL 
    BEGIN 
        RAISERROR('Ride not found.', 16, 1); 
        RETURN;
    END
    
    IF @status <> 'completed' 
    BEGIN 
        RAISERROR('Can only rate completed rides.', 16, 1); 
        RETURN;
    END

    IF @rater_role = 'passenger'
    BEGIN
        IF EXISTS (
            SELECT 1 
            FROM taxi.rides 
            WHERE ride_id = @ride_id 
                AND passenger_rating_to_driver IS NOT NULL
        )
        BEGIN 
            RAISERROR('Passenger has already rated this ride.', 16, 1);
            RETURN; 
        END
            
        UPDATE taxi.rides 
        SET passenger_rating_to_driver = @rating,
            comment = ISNULL(@comment, comment) 
        WHERE ride_id = @ride_id;
    END
    ELSE IF @rater_role = 'driver'
    BEGIN
        IF EXISTS (
            SELECT 1 
            FROM taxi.rides
            WHERE ride_id = @ride_id 
                AND driver_rating_to_passenger IS NOT NULL
            )
            BEGIN 
                RAISERROR('Driver has already rated this ride.', 16, 1);
                RETURN;
            END
            
        UPDATE taxi.rides 
        SET driver_rating_to_passenger = @rating
        WHERE ride_id = @ride_id;
    END
    ELSE 
    BEGIN
        RAISERROR('Invalid rater role.', 16, 1);
        RETURN;
    END
END
GO


-- 4. Read APIs for Backend


CREATE OR ALTER PROCEDURE taxi.sp_get_passenger_active_ride
    @passenger_id INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ride_id, driver_id, vehicle_id, service_type, 
        origin_latitude, origin_longitude, destination_latitude, destination_longitude, 
        ride_status, ride_payment_status, calculated_price
    FROM taxi.rides
    WHERE passenger_id = @passenger_id 
      AND ride_status NOT IN ('completed', 'cancelled');
END
GO

CREATE OR ALTER PROCEDURE taxi.sp_get_driver_new_offers
    @driver_id INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        o.ride_offer_id, o.origin_latitude, o.origin_longitude, 
        o.destination_latitude, o.destination_longitude, 
        o.calculated_price, o.is_prepaid, o.expires_at
    FROM taxi.ride_offer_candidates c
    JOIN taxi.ride_offers o ON c.offer_id = o.ride_offer_id
    WHERE c.driver_id = @driver_id 
      AND c.response_status = 'pending'
      AND o.expires_at > GETDATE();
END
GO

CREATE OR ALTER PROCEDURE taxi.sp_get_passenger_ride_history
    @passenger_id INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ride_id, service_type, ride_status, ride_payment_status, 
        calculated_price, requested_at, completed_at
    FROM taxi.rides
    WHERE passenger_id = @passenger_id 
      AND ride_status IN ('completed', 'cancelled')
    ORDER BY requested_at DESC;
END
GO


-- 5. Views


CREATE OR ALTER VIEW taxi.vw_available_drivers AS
SELECT 
    d.driver_id,
    d.user_id,
    d.driver_status,
    d.average_rating,
    dl.latitude, dl.longitude,
    dl.updated_at AS location_updated_at,
    v.vehicle_id,
    v.vehicle_type,
    v.license_plate
FROM taxi.drivers d
JOIN taxi.driver_locations dl 
    ON dl.driver_id = d.driver_id
JOIN taxi.vehicles v 
    ON v.owner_id = d.driver_id 
    AND v.is_active_now = 1
WHERE d.driver_status = 'available';
GO
 
CREATE OR ALTER VIEW taxi.vw_active_ride_offers AS
SELECT 
    ro.ride_offer_id,
    ro.passenger_id,
    ro.vehicle_type,
    ro.service_type,
    ro.calculated_price,
    ro.requested_at,
    ro.expires_at,
    COUNT(roc.ride_offer_candidate_id) AS candidate_count,
    SUM(CASE WHEN roc.response_status = 'pending' THEN 1 ELSE 0 END) AS pending_candidates
FROM taxi.ride_offers ro
LEFT JOIN taxi.ride_offer_candidates roc 
    ON roc.offer_id = ro.ride_offer_id
WHERE ro.expires_at > GETDATE()
GROUP BY ro.ride_offer_id, ro.passenger_id, 
    ro.vehicle_type, ro.service_type, ro.calculated_price, 
    ro.requested_at, ro.expires_at;
GO
 
CREATE OR ALTER VIEW taxi.vw_ongoing_rides AS
SELECT 
    r.ride_id,
    r.passenger_id,
    r.driver_id,
    r.vehicle_id,
    r.service_type,
    r.ride_status,
    r.calculated_price,
    r.requested_at,
    r.started_at
FROM taxi.rides r
WHERE r.ride_status IN ('to_origin','to_destination');
GO
 
CREATE OR ALTER VIEW taxi.vw_driver_earnings_summary AS
SELECT 
    d.driver_id,
    d.user_id,
    dw.balance AS wallet_balance,
    COUNT(r.ride_id) AS completed_ride_count,
    SUM(r.calculated_price - ISNULL(r.allocated_discount,0)) AS total_ride_revenue
FROM taxi.drivers d
JOIN taxi.driver_wallets dw ON dw.driver_id = d.driver_id
LEFT JOIN taxi.rides r 
    ON r.driver_id = d.driver_id AND r.ride_status = 'completed'
GROUP BY d.driver_id, d.user_id, dw.balance;
GO

CREATE OR ALTER VIEW taxi.vw_driver_ranking AS
SELECT 
    driver_id,
    user_id,
    average_rating,
    rating_count,
    activity_points,
    DENSE_RANK() OVER 
        (ORDER BY average_rating DESC, activity_points DESC) AS rank_position
FROM taxi.drivers;
GO

CREATE OR ALTER VIEW taxi.vw_passenger_ranking AS
SELECT 
    user_id,
    average_score,
    score_count,
    activity_score,
    DENSE_RANK() OVER (ORDER BY average_score DESC, activity_score DESC) AS rank_position
FROM taxi.passenger_stats;
GO


-- 6. Triggers


CREATE OR ALTER TRIGGER taxi.trg_vehicles_enforce_single_active
ON taxi.vehicles
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL() > 1 RETURN;

    IF UPDATE(is_active_now)
    BEGIN
        UPDATE v
        SET v.is_active_now = 0
        FROM taxi.vehicles v
        JOIN inserted i ON v.owner_id = i.owner_id
        WHERE i.is_active_now = 1 AND v.vehicle_id <> i.vehicle_id;
    END
END
GO

CREATE OR ALTER TRIGGER taxi.trg_drivers_after_insert
ON taxi.drivers
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @driver_id INT, @user_id INT;
    DECLARE cur_inserted CURSOR LOCAL FAST_FORWARD FOR 
    SELECT driver_id, user_id 
    FROM inserted;

    OPEN cur_inserted;
    
    FETCH NEXT FROM cur_inserted INTO @driver_id, @user_id;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @new_json NVARCHAR(MAX) = 
            (SELECT * FROM inserted WHERE driver_id = @driver_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        
        EXEC taxi.sp_write_log @actor_id = @user_id, @operation_type = 'insert', 
            @target_table = 'drivers', @target_id = @driver_id, 
            @new_value = @new_json, @description = 'New driver registered', 
            @driver_id = @driver_id;

        FETCH NEXT FROM cur_inserted INTO @driver_id, @user_id;
    END
    
    CLOSE cur_inserted; 
    DEALLOCATE cur_inserted;
END
GO

CREATE OR ALTER TRIGGER taxi.trg_vehicles_after_insert
ON taxi.vehicles
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vehicle_id INT, @owner_id INT;
    DECLARE cur_inserted CURSOR LOCAL FAST_FORWARD FOR 
    SELECT vehicle_id, owner_id 
    FROM inserted;
    
    OPEN cur_inserted;
    FETCH NEXT FROM cur_inserted INTO @vehicle_id, @owner_id;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @new_json NVARCHAR(MAX) = 
            (SELECT * FROM inserted WHERE vehicle_id = @vehicle_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        
        EXEC taxi.sp_write_log @operation_type = 'insert', @target_table = 'vehicles', 
            @target_id = @vehicle_id, @new_value = @new_json, 
            @description = 'New vehicle registered', @driver_id = @owner_id;
        
        FETCH NEXT FROM cur_inserted INTO @vehicle_id, @owner_id;
    END
    
    CLOSE cur_inserted;
    DEALLOCATE cur_inserted;
END
GO

CREATE OR ALTER TRIGGER taxi.trg_rides_after_insert
ON taxi.rides
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 
        FROM inserted i 
        WHERE taxi.fn_vehicle_supports_service(i.vehicle_id, i.service_type) = 0)
    BEGIN
        RAISERROR('Vehicle does not support the requested service type.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
 
    DECLARE @ride_id INT, @passenger_id INT;
    DECLARE cur_inserted CURSOR LOCAL FAST_FORWARD FOR 
    SELECT ride_id, passenger_id 
    FROM inserted;

    OPEN cur_inserted;
    FETCH NEXT FROM cur_inserted INTO @ride_id, @passenger_id;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @new_json NVARCHAR(MAX) = 
        (SELECT * FROM inserted WHERE ride_id = @ride_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        
        EXEC taxi.sp_write_log @actor_id = @passenger_id, @operation_type = 'insert', 
            @target_table = 'rides', @target_id = @ride_id, @new_value = @new_json, 
            @description = 'New ride created', @ride_id = @ride_id;
        
        FETCH NEXT FROM cur_inserted INTO @ride_id, @passenger_id;
    END
    
    CLOSE cur_inserted;
    DEALLOCATE cur_inserted;
END
GO

CREATE OR ALTER TRIGGER taxi.trg_rides_log_status_change
ON taxi.rides
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(ride_status) RETURN;

    DECLARE @ride_id INT;
    DECLARE cur_status CURSOR LOCAL FAST_FORWARD FOR
        SELECT i.ride_id 
        FROM inserted i 
        JOIN deleted de ON de.ride_id = i.ride_id 
        WHERE i.ride_status <> de.ride_status;
 
    OPEN cur_status;
    FETCH NEXT FROM cur_status INTO @ride_id;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @old_json NVARCHAR(MAX) = 
            (SELECT * FROM deleted WHERE ride_id = @ride_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        DECLARE @new_json NVARCHAR(MAX) = 
            (SELECT * FROM inserted WHERE ride_id = @ride_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        EXEC taxi.sp_write_log @operation_type = 'update', @target_table = 'rides', 
            @target_id = @ride_id, @old_value = @old_json, @new_value = @new_json, 
            @description = 'Ride status changed', @ride_id = @ride_id;
        
        FETCH NEXT FROM cur_status INTO @ride_id;
    END
    
    CLOSE cur_status;
    DEALLOCATE cur_status;
END
GO

CREATE OR ALTER TRIGGER taxi.trg_rides_log_rating
ON taxi.rides
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ride_id INT;

    IF UPDATE(passenger_rating_to_driver)
    BEGIN
        DECLARE cur_p_rating CURSOR LOCAL FAST_FORWARD FOR
            SELECT i.ride_id 
            FROM inserted i 
            JOIN deleted de ON de.ride_id = i.ride_id 
            WHERE i.passenger_rating_to_driver IS NOT NULL 
                AND de.passenger_rating_to_driver IS NULL;
        
        OPEN cur_p_rating; FETCH NEXT FROM cur_p_rating INTO @ride_id;
        
        WHILE @@FETCH_STATUS = 0 BEGIN
            DECLARE @old_json_p NVARCHAR(MAX) = 
                (SELECT * FROM deleted WHERE ride_id = @ride_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            DECLARE @new_json_p NVARCHAR(MAX) = 
                (SELECT * FROM inserted WHERE ride_id = @ride_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

            EXEC taxi.sp_write_log @operation_type = 'update', @target_table = 'rides', 
                @target_id = @ride_id, @old_value = @old_json_p, @new_value = @new_json_p, 
                @description = 'Passenger rated the driver', @ride_id = @ride_id;
            
            FETCH NEXT FROM cur_p_rating INTO @ride_id;
        END
        
        CLOSE cur_p_rating;
        DEALLOCATE cur_p_rating;
    END

    IF UPDATE(driver_rating_to_passenger)
    BEGIN
        DECLARE cur_d_rating CURSOR LOCAL FAST_FORWARD FOR
            SELECT i.ride_id 
            FROM inserted i 
            JOIN deleted de ON de.ride_id = i.ride_id 
            WHERE i.driver_rating_to_passenger IS NOT NULL 
                AND de.driver_rating_to_passenger IS NULL;

        OPEN cur_d_rating; FETCH NEXT FROM cur_d_rating INTO @ride_id;
        WHILE @@FETCH_STATUS = 0 BEGIN
            DECLARE @old_json_d NVARCHAR(MAX) = 
                (SELECT * FROM deleted WHERE ride_id = @ride_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            DECLARE @new_json_d NVARCHAR(MAX) = 
                (SELECT * FROM inserted WHERE ride_id = @ride_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

            EXEC taxi.sp_write_log @operation_type = 'update', @target_table = 'rides', 
                @target_id = @ride_id, @old_value = @old_json_d, @new_value = @new_json_d,
                @description = 'Driver rated the passenger', @ride_id = @ride_id;
            
            FETCH NEXT FROM cur_d_rating INTO @ride_id;
        END
        
        CLOSE cur_d_rating;
        DEALLOCATE cur_d_rating;
    END
END
GO

CREATE OR ALTER TRIGGER taxi.trg_rides_update_metrics
ON taxi.rides
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL() > 1 RETURN;

    IF UPDATE(passenger_rating_to_driver)
    BEGIN
        UPDATE d
        SET
            d.average_rating = (d.average_rating * d.rating_count + i.passenger_rating_to_driver) / (d.rating_count + 1),
            d.rating_count = d.rating_count + 1,
            d.activity_points = d.activity_points + 10 
        FROM taxi.drivers d
        JOIN inserted i 
            ON i.driver_id = d.driver_id
        JOIN deleted de
            ON de.ride_id = i.ride_id
        WHERE i.passenger_rating_to_driver IS NOT NULL 
            AND de.passenger_rating_to_driver IS NULL;
    END

    IF UPDATE(driver_rating_to_passenger)
    BEGIN
        MERGE taxi.passenger_stats AS target
        USING (
            SELECT i.passenger_id, i.driver_rating_to_passenger 
            FROM inserted i
            JOIN deleted de 
                ON de.ride_id = i.ride_id
            WHERE i.driver_rating_to_passenger IS NOT NULL 
                AND de.driver_rating_to_passenger IS NULL
        ) AS src
        ON target.user_id = src.passenger_id
        WHEN MATCHED THEN
            UPDATE SET
                average_score = (target.average_score * target.score_count + src.driver_rating_to_passenger) / (target.score_count + 1),
                score_count = target.score_count + 1,
                activity_score = target.activity_score + 5
        WHEN NOT MATCHED THEN
            INSERT (user_id, average_score, score_count, activity_score)
            VALUES (src.passenger_id, src.driver_rating_to_passenger, 1, 5);
    END
END
GO


-- 7. Database Roles & Security Permissions

GRANT SELECT ON taxi.vw_available_drivers TO readonly_analyst;
GRANT SELECT ON taxi.vw_active_ride_offers TO readonly_analyst;
GRANT SELECT ON taxi.vw_ongoing_rides TO readonly_analyst;
GRANT SELECT ON taxi.vw_driver_earnings_summary TO readonly_analyst;
GRANT SELECT ON taxi.vw_driver_ranking TO readonly_analyst;
GRANT SELECT ON taxi.vw_passenger_ranking TO readonly_analyst;

GO