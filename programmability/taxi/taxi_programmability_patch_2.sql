USE mini_snapp
GO

ALTER PROCEDURE taxi.sp_pay_for_ride
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