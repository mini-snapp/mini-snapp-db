USE mini_snapp;
GO


PRINT '--- STEP 1: Register New User --';

DECLARE @customer_role_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @new_user_id INT;

EXEC core.sp_register_user 
    @username = 'demo_user', 
    @password_hash = 'my_secure_hash_123', 
    @first_name = 'Ali', 
    @last_name = 'Rezaei', 
    @registration_phone = '09301112233', 
    @email = 'ali.demo@example.com', 
    @role_id = @customer_role_id, 
    @new_user_id = @new_user_id OUTPUT;


SELECT 
    u.user_id, u.username, u.registration_phone, 
    r.role_name, 
    w.balance AS wallet_balance
FROM core.users u
JOIN core.roles r ON u.role_id = r.role_id
JOIN core.user_wallets w ON u.user_id = w.user_id
WHERE u.username = 'demo_user';
GO


PRINT '--- STEP 2: Check User Exists ---';


EXEC core.sp_check_user_exists 
    @username = 'demo_user', 
    @registration_phone = '09301112233', 
    @email = 'ali.demo@example.com';
GO


PRINT '--- STEP 3: Verify Login ---';


EXEC core.sp_verify_login 
    @username = 'demo_user', 
    @input_password_hash = 'my_secure_hash_123';



EXEC core.sp_verify_login 
    @username = 'demo_user', 
    @input_password_hash = 'wrong_password_!!!';
GO

PRINT '--- STEP 4: Get User Profile ---';

DECLARE @uid INT = (SELECT user_id FROM core.users WHERE username = 'demo_user');


EXEC core.sp_get_user_profile @user_id = @uid;
GO


PRINT '--- STEP 5: Block User and Test Login ---';

UPDATE core.users 
SET is_blocked = 1 
WHERE username = 'demo_user';

SELECT username, is_blocked, deleted_at FROM core.users WHERE username = 'demo_user';



EXEC core.sp_verify_login 
    @username = 'demo_user', 
    @input_password_hash = 'my_secure_hash_123';
GO


PRINT '--- STEP 6: Soft Delete User and Test Login ---';

UPDATE core.users 
SET deleted_at = GETDATE() 
WHERE username = 'demo_user';


SELECT username, is_blocked, deleted_at FROM core.users WHERE username = 'demo_user';



EXEC core.sp_verify_login 
    @username = 'demo_user', 
    @input_password_hash = 'my_secure_hash_123';
GO

PRINT '--- STEP 7: Check Audit Logs (Trigger action) ---';

DECLARE @uid INT = (SELECT user_id FROM core.users WHERE username = 'demo_user');


SELECT 
    operation_type, schema_name, target_table, 
    description, created_at 
FROM core.core_logs 
WHERE target_table = 'users' 
  AND target_id = CAST(@uid AS VARCHAR);
GO


PRINT '--- STEP 8: Edge Case - Duplicate Phone Number ---';

DECLARE @customer_role_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @dummy_id INT;

BEGIN TRY
   
    EXEC core.sp_register_user 
        @username = 'hacker_user', 
        @password_hash = 'hash', 
        @registration_phone = '09301112233', 
        @role_id = @customer_role_id, 
        @new_user_id = @dummy_id OUTPUT;
END TRY
BEGIN CATCH
    
    SELECT 
        ERROR_MESSAGE() AS Database_Error_Message,
        'Registration Failed as expected due to UNIQUE constraint!' AS Status;
END CATCH
GO