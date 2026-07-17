USE mini_snapp;
GO


CREATE OR ALTER PROCEDURE core.sp_check_user_exists
    @username VARCHAR(50) = NULL,
    @registration_phone VARCHAR(15) = NULL,
    @email VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        CAST(CASE WHEN EXISTS (SELECT 1 FROM core.users WHERE username = @username) THEN 1 ELSE 0 END AS BIT) AS username_exists,
        CAST(CASE WHEN EXISTS (SELECT 1 FROM core.users WHERE registration_phone = @registration_phone) THEN 1 ELSE 0 END AS BIT) AS phone_exists,
        CAST(CASE WHEN EXISTS (SELECT 1 FROM core.users WHERE email = @email) THEN 1 ELSE 0 END AS BIT) AS email_exists;
END
GO

CREATE OR ALTER PROCEDURE core.sp_get_user_profile
    @user_id INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        u.user_id, 
        u.username, 
        u.first_name, 
        u.last_name, 
        u.registration_phone, 
        u.email,
        u.created_at,
        r.role_name,
        r.hierarchy_level,
        w.balance
    FROM core.users u
    JOIN core.roles r ON u.role_id = r.role_id
    LEFT JOIN core.user_wallets w ON u.user_id = w.user_id
    WHERE u.user_id = @user_id 
      AND u.deleted_at IS NULL;
END
GO

CREATE OR ALTER PROCEDURE core.sp_get_available_coupons
AS
BEGIN
    SET NOCOUNT ON;

    SELECT * FROM core.vw_active_coupons;
END

GO


CREATE OR ALTER PROCEDURE core.sp_verify_login
    @username VARCHAR(50),
    @input_password_hash VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @user_id INT;
    DECLARE @stored_hash VARCHAR(255);
    DECLARE @is_blocked BIT;
    DECLARE @deleted_at DATETIME;
    DECLARE @role_id INT;
    
    SELECT 
        @user_id = user_id,
        @stored_hash = password_hash,
        @is_blocked = is_blocked,
        @deleted_at = deleted_at,
        @role_id = role_id
    FROM core.users 
    WHERE username = @username;


    IF @user_id IS NULL
    BEGIN
        SELECT 0 AS is_success, 'Invalid username or password' AS [message], NULL AS user_id, NULL AS role_id;
        RETURN;
    END


    IF @deleted_at IS NOT NULL
    BEGIN
        SELECT 0 AS is_success, 'Account has been deleted' AS [message], NULL AS user_id, NULL AS role_id;
        RETURN;
    END

    IF @is_blocked = 1
    BEGIN
        SELECT 0 AS is_success, 'Account is temporarily blocked' AS [message], NULL AS user_id, NULL AS role_id;
        RETURN;
    END


    IF @stored_hash <> @input_password_hash
    BEGIN
        SELECT 0 AS is_success, 'Invalid username or password' AS [message], NULL AS user_id, NULL AS role_id;
        RETURN;
    END

    SELECT 
        1 AS is_success, 
        'Login successful' AS [message], 
        @user_id AS user_id, 
        @role_id AS role_id;
END
GO