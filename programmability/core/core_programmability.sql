USE mini_snapp
GO

-- Stored procedures (helper first)

CREATE PROCEDURE core.sp_write_log
    @actor_id INT ,
    @operation_type VARCHAR(10),
    @schema_name VARCHAR(10),
    @target_table varchar(50),
    @target_id varchar(50),
    @old_value NVARCHAR(MAX) = NULL,
    @new_value NVARCHAR(MAX) = NULL,
    @description VARCHAR(500) = NULL

AS
BEGIN

    SET NOCOUNT ON; -- optimize masalan :]

    INSERT INTO core.core_logs
        (actor_id , operation_type , schema_name , target_table ,
            target_id , old_value , new_value , [description])
    VALUES
        (@actor_id, @operation_type, @schema_name, @target_table,
             @target_id, @old_value, @new_value, @description);

END



GO

CREATE PROCEDURE core.sp_register_user
    @username VARCHAR(50),
    @password_hash VARCHAR(255),
    @first_name VARCHAR(50) = NULL,
    @last_name VARCHAR(50) = NULL,
    @registration_phone VARCHAR(15) = NULL,
    @email VARCHAR(100) = NULL,
    @role_id INT,
    @new_user_id INT OUTPUT
AS
BEGIN

    SET NOCOUNT ON;

    BEGIN TRY

        BEGIN TRANSACTION;

        INSERT INTO core.users
            (username, password_hash , first_name,last_name ,
                registration_phone , email , role_id)
        VALUES
            (@username , @password_hash , @first_name , @last_name , 
                @registration_phone , @email , @role_id);
            
        SET @new_user_id = SCOPE_IDENTITY();

        INSERT INTO core.user_wallets 
            (user_id ,balance)
        VALUES
            (@new_user_id , 0);

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT >0
            ROLLBACK TRANSACTION;
        
        ;THROW;
    end CATCH
END


GO  

CREATE PROCEDURE core.sp_charge_wallet
    @user_id INT,
    @amount DECIMAL(10,2),
    @payment_method VARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;

    IF @amount <=0
    BEGIN
        ;RAISERROR('Charge amount must be positive',16,1);
        RETURN;
    END
    BEGIN TRY
        BEGIN TRANSACTION
        
        INSERT INTO core.transactions
            (user_id ,transaction_type , transaction_status , 
                amount , payment_method)
        VALUES 
            (@user_id , 'wallet_charge' , 'completed', @amount , @payment_method);

        UPDATE core.user_wallets 
        SET balance = balance + @amount
        WHERE user_id = @user_id

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('No wallet found for this user.' , 16 ,1); 
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        ;THROW;
    END CATCH
END


GO  

CREATE PROCEDURE core.sp_assign_admin_role
    @user_id INT ,
    @admin_identifier VARCHAR(20),
    @access_level VARCHAR(20)
AS
BEGIN

    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM core.admins WHERE user_id = @user_id)
    BEGIN
        RAISERROR('This user is already and admin.',16,1);
        RETURN; 
    END

    DECLARE @admin_role_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'admin');

    IF @admin_role_id IS NULL
    BEGIN
        RAISERROR('Role "admin" does not exist in core.roles.', 16 ,1);
        RETURN; 
    END


    BEGIN TRY
        BEGIN TRANSACTION;
        
        INSERT INTO core.admins 
            (user_id, admin_identifier , access_level)
        VALUES
            (@user_id , @admin_identifier , @access_level);

        UPDATE core.users
        SET role_id = @admin_role_id
        WHERE user_id = @user_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        ;THROW;
    END CATCH
END


GO 
-- coupon validation functions : 

CREATE FUNCTION core.fn_validate_coupon
(
    @coupon_code VARCHAR(20),
    @user_id INT ,
    @order_amount DECIMAL(10,2)
)
RETURNS BIT
AS
BEGIN

    DECLARE @is_valid BIT = 1;

    DECLARE @coupon_id INT;
    DECLARE @is_active BIT;
    DECLARE @expiry_date DATETIME;
    DECLARE @current_usage INT;
    DECLARE @max_usage INT;
    DECLARE @min_requirment DECIMAL(10 , 2);


    SELECT
        @coupon_id = coupon_id,
        @is_active = is_active,
        @expiry_date = [expiry_date],
        @current_usage = current_usage,
        @max_usage = max_usage,
        @min_requirment = min_requirement
    FROM core.coupons 
    WHERE code = @coupon_code;

    IF @coupon_id IS NULL 
        SET @is_valid = 0;

    ELSE IF @is_active = 0
        SET @is_valid = 0;
    
    ELSE IF @expiry_date IS NOT NULL AND @expiry_date < GETDATE()
        SET @is_valid = 0;
    
    ELSE IF @current_usage >= @max_usage
        SET @is_valid = 0;
    
    ELSE IF @min_requirment IS NOT NULL AND @order_amount < @min_requirment
        SET @is_valid = 0;
    
    ELSE IF EXISTS (
        SELECT 1 FROM core.coupon_usages
        WHERE coupon_id = @coupon_id  AND user_id = @user_id
    )
        SET @is_valid = 0;
    

    RETURN @is_valid;
END



GO 
CREATE PROCEDURE core.sp_apply_coupon
    @coupon_code VARCHAR(20),
    @user_id INT ,
    @order_amount DECIMAL(10,2),
    @order_id INT = NULL , 
    @ride_id INT = NULL 
AS
BEGIN
    SET NOCOUNT ON;

    IF @order_id IS NULL AND @ride_id IS NULL 
    BEGIN
        RAISERROR('Either order_id or ride_id must be provided.', 16 ,1);
        RETURN;
    END

    DECLARE @is_valid BIT ;

    SET @is_valid = core.fn_validate_coupon(@coupon_code , @user_id , @order_amount);


    IF @is_valid = 0
    BEGIN
        RAISERROR('Coupon is not valid for this user/order.',16,1);
        RETURN; 
    END

    DECLARE @coupon_id INT = (SELECT coupon_id FROM core.coupons WHERE code = @coupon_code)

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO core.coupon_usages
            (coupon_id , user_id , order_id , ride_id)
        VALUES
            (@coupon_id , @user_id , @order_id , @ride_id);
        
        UPDATE core.coupons
        SET current_usage = current_usage +1
        WHERE coupon_id = @coupon_id

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT >0
            ROLLBACK TRANSACTION;

            ;THROW;
    
    END CATCH
END

GO

CREATE FUNCTION core.fn_calculate_distance_km
(
    @lat1 DECIMAL(10,8),
    @lng1 DECIMAL(11,8),
    @lat2 DECIMAL(10,8),
    @lng2 DECIMAL(11,8)
)
RETURNS DECIMAL(10,2)
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @earth_radius_km DECIMAL(10,4) = 6371.0;
    DECLARE @d_lat FLOAT = RADIANS(CAST(@lat2 - @lat1 AS FLOAT));
    DECLARE @d_lng FLOAT = RADIANS(CAST(@lng2 - @lng1 AS FLOAT));

    DECLARE @a FLOAT = 
        SIN(@d_lat/2) * SIN(@d_lat/2) +
        COS(RADIANS(CAST(@lat1 AS FLOAT))) * COS(RADIANS(CAST(@lat2 AS FLOAT))) *
        SIN(@d_lng /2) * SIN(@d_lng/2);

    DECLARE @c FLOAT = 2 * ATN2(SQRT(@a) , SQRT(1 - @a));

    RETURN CAST (@earth_radius_km * @c AS DECIMAL(10,2));
    
END


GO

CREATE FUNCTION core.fn_has_minimum_role_level
(
    @user_id INT, 
    @required_level INT
)
RETURNS BIT
AS 
BEGIN

    DECLARE @user_level INT;
    DECLARE @result BIT = 0;

    SELECT @user_level = r.hierarchy_level
    FROM core.users u 
    JOIN core.roles r ON u.role_id = r.role_id
    WHERE u.user_id = @user_id

    IF @user_level >= @required_level
        SET @result = 1;

    RETURN @result;

END


GO


CREATE FUNCTION core.fn_get_active_commission_rate
(
    @service_type VARCHAR(20),
    @check_date DATETIME = NULL
)
RETURNS TABLE
AS
Return
(
    SELECT TOP 1
        commission_rate_id,
        service_type,
        driver_share,
        restaurant_share,
        app_share,
        effective_from,
        effective_to
    FROM core.commission_rates
    WHERE service_type = @service_type 
        AND effective_from <= ISNULL(@check_date , GETDATE())
        AND (effective_to IS NULL OR effective_to > ISNULL(@check_date , GETDATE()))
    ORDER BY effective_from DESC
);

GO

-- views


CREATE VIEW core.vw_active_coupons AS
SELECT
    coupon_id,
    code,
    [percentage],
    amount,
    min_requirement,
    max_cap,
    [expiry_date],
    current_usage,
    max_usage,
    (max_usage - current_usage) AS remaining_uses
FROM core.coupons
WHERE is_active = 1
    AND (expiry_date IS NULL OR expiry_date > GETDATE())
    AND current_usage < max_usage;

GO

CREATE VIEW core.vw_user_roles_permissions AS
SELECT
   u.user_id,
    u.username,
    r.role_name,
    r.hierarchy_level,
    p.permissions_name
FROM core.users u 
JOIN core.roles r ON u.role_id = r.role_id
LEFT JOIN core.role_permissions rp ON r.role_id = rp.role_id
LEFT JOIN core.permissions p ON rp.permission_id = p.permission_id;

GO


CREATE VIEW core.vw_wallet_summary AS
SELECT
    u.user_id,
    u.username,
    uw.balance
FROM core.users u 
JOIN core.user_wallets uw ON uw.user_id = u.user_id


Go 

CREATE VIEW core.vw_open_complaints AS
SELECT 
   c.complaint_id,
    c.title,
    c.target_type,
    c.target_id,
    c.complaint_status,
    reporter.username AS reporter_username,
    admin_user.username AS assigned_admin_username,
    c.created_at
FROM core.complaints c 
JOIN core.users reporter ON c.reporter_id = reporter.user_id 
LEFT JOIN core.admins a ON c.assigned_admin_id= a.admin_id
LEFT JOIN core.users admin_user ON admin_user.user_id = a.user_id
WHERE c.complaint_status IN ('open' , 'in_review');

GO


-- trigger

CREATE TRIGGER core.trg_users_after_insert
ON core.users
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @user_id INT;
    DECLARE @username VARCHAR(50);
    DECLARE @log_desc VARCHAR(150);

    DECLARE cur_inserted CURSOR FOR
    SELECT user_id  ,username FROM inserted;

    OPEN cur_inserted;
    FETCH NEXT FROM cur_inserted INTO @user_id , @username;

    WHILE @@FETCH_STATUS = 0
    BEGIN

        SET @log_desc = 'New user registered: ' + ISNULL(@username, 'Unknown');

        EXEC core.sp_write_log
        @actor_id = @user_id,
        @operation_type = 'insert',
        @schema_name = 'core',
        @target_table = 'users',
        @target_id = @user_id ,
        @description = @log_desc;

        FETCH NEXT FROM cur_inserted INTO @user_id , @username;
    END

    CLOSE cur_inserted;
    DEALLOCATE cur_inserted;
    
END

GO 

CREATE TRIGGER core.trg_transactions_after_insert
ON core.transactions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
 
    DECLARE @transaction_id INT;
    DECLARE @user_id INT;
    DECLARE @amount DECIMAL(10,2);
    DECLARE @type VARCHAR(20);
    

    DECLARE cur_inserted CURSOR FOR
    SELECT
        transaction_id,
        user_id,
        amount,
        transaction_type
    FROM inserted;

    OPEN cur_inserted ;
    FETCH NEXT FROM cur_inserted INTO 
        @transaction_id , @user_id , @amount , @type;


    WHILE @@FETCH_STATUS = 0
    BEGIN

        DECLARE @log_desc VARCHAR(150)=
             @type + ' of amount ' + CAST(@amount AS VARCHAR(20));

        EXEC core.sp_write_log
        @actor_id       = @user_id,
        @operation_type = 'insert',
        @schema_name    = 'core',
        @target_table   = 'transactions',
        @target_id      = @transaction_id,
        @description    = @log_desc;

        FETCH NEXT FROM cur_inserted INTO 
        @transaction_id , @user_id , @amount , @type;
    END
 
    CLOSE cur_inserted;
    DEALLOCATE cur_inserted;
END

GO


CREATE TRIGGER core.trg_admins_after_insert
ON core.admins
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @admin_role_id INT;
    SET @admin_role_id = (SELECT role_id FROM core.roles WHERE role_name = 'admin');

    -- update role
    IF @admin_role_id IS NOT NULL
    BEGIN
        UPDATE u
        SET role_id = @admin_role_id
        FROM core.users u 
        JOIN inserted i ON i.user_id = u.user_id
        WHERE u.role_id <> @admin_role_id OR role_id IS NULL; 
    END



 
    DECLARE @admin_id INT;
    DECLARE @user_id INT;
    
    DECLARE cur_inserted CURSOR FOR
    SELECT admin_id, user_id FROM inserted;

    OPEN cur_inserted ;
    FETCH NEXT FROM cur_inserted INTO 
        @admin_id, @user_id;


    WHILE @@FETCH_STATUS = 0
    BEGIN

        EXEC core.sp_write_log
            @actor_id       = @user_id,
            @operation_type = 'insert',
            @schema_name    = 'core',
            @target_table   = 'admins',
            @target_id      = @admin_id,
            @description    = 'User promoted to admin';

        FETCH NEXT FROM cur_inserted INTO 
            @admin_id, @user_id;
    END
 
    CLOSE cur_inserted;
    DEALLOCATE cur_inserted;

END
GO

CREATE TRIGGER core.trg_coupons_after_update
ON core.coupons
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
 
    IF TRIGGER_NESTLEVEL() > 1 RETURN;
    -- Auto deactivate coupons 
    UPDATE c
    SET is_active = 0
    FROM core.coupons c
    JOIN inserted i ON c.coupon_id = i.coupon_id
    WHERE i.current_usage >= i.max_usage
      AND c.is_active = 1;
 
    DECLARE @coupon_id INT;
    DECLARE @code VARCHAR(20);
    DECLARE @log_desc VARCHAR(150);

    DECLARE cur_inserted CURSOR FOR
    SELECT coupon_id,code FROM inserted;

    OPEN cur_inserted;
    FETCH NEXT FROM cur_inserted INTO 
        @coupon_id , @code ;
 
    WHILE @@FETCH_STATUS = 0
    BEGIN  
        SET @log_desc = 
            'Coupon updated: ' + ISNULL(@code, 'Unknown Code');;

            
        EXEC core.sp_write_log
            @actor_id       = NULL,
            @operation_type = 'update',
            @schema_name    = 'core',
            @target_table   = 'coupons',
            @target_id      = @coupon_id,
            @description    = @log_desc;


        FETCH NEXT FROM cur_inserted INTO 
        @coupon_id , @code ;
    
    END
    CLOSE cur_inserted;
    DEALLOCATE cur_inserted;

END

GO


