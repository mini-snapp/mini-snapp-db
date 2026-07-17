USE mini_snapp;
GO


ALTER PROCEDURE taxi.sp_register_driver
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