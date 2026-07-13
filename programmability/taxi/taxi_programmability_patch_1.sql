USE mini_snapp

GO

CREATE PROCEDURE taxi.sp_pay_for_ride
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

CREATE PROCEDURE taxi.sp_start_ride_to_origin
    @ride_id INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC taxi.sp_update_ride_status @ride_id, 'to_origin';
END
GO

GO

ALTER PROCEDURE taxi.sp_create_ride_offer
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

ALTER PROCEDURE taxi.sp_respond_to_ride_offer
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

ALTER PROCEDURE taxi.sp_update_ride_status
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

ALTER PROCEDURE taxi.sp_complete_ride
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
 
    IF @driver_share IS NULL 
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


ALTER PROCEDURE taxi.sp_cancel_ride
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


USE mini_snapp;
GO

ALTER PROCEDURE taxi.sp_rate_ride
    @ride_id INT,
    @rater_role VARCHAR(15), 
    @rating INT,
    @comment TEXT = NULL
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