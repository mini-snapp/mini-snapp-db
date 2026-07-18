USE mini_snapp;
GO


PRINT '--- SCENARIO 4 | STEP 1: Register Normal User ---';
DECLARE @customer_role_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @new_admin_uid INT;
EXEC core.sp_register_user 'future_admin', 'hash', 'Admin', 'Test', '09901112233', NULL, @customer_role_id, @new_admin_uid OUTPUT;


DECLARE @has_access BIT = core.fn_has_minimum_role_level(@new_admin_uid, 5);
SELECT 'future_admin' AS Username, @has_access AS Has_Admin_Access;

PRINT '--- SCENARIO 4 | STEP 2: Promote to Admin ---';

EXEC core.sp_assign_admin_role @user_id = @new_admin_uid, @admin_identifier = 'ADM-999', @access_level = 'limited';


SET @has_access = core.fn_has_minimum_role_level(@new_admin_uid, 5);
SELECT u.username, r.role_name, @has_access AS Has_Admin_Access_Now
FROM core.users u JOIN core.roles r ON u.role_id = r.role_id
WHERE u.user_id = @new_admin_uid;



PRINT '--- SCENARIO 5 | STEP 1: Submit New Complaint (Open) ---';
DECLARE @u_id INT = (SELECT user_id FROM core.users WHERE username = 'future_admin');
INSERT INTO core.complaints (reporter_id, target_type, target_id, title, complaint_description, complaint_status)
VALUES (@u_id, 'branch', 10, 'Terrible packaging', 'The food spilled everywhere!', 'open');
DECLARE @comp_id INT = SCOPE_IDENTITY();


SELECT complaint_id, title, complaint_status, assigned_admin_username 
FROM core.vw_open_complaints WHERE complaint_id = @comp_id;

PRINT '--- SCENARIO 5 | STEP 2: Admin Picks Up Complaint (In Review) ---';

DECLARE @admin_id INT = (SELECT admin_id FROM core.admins WHERE user_id = @u_id);
UPDATE core.complaints SET complaint_status = 'in_review', assigned_admin_id = @admin_id WHERE complaint_id = @comp_id;


SELECT complaint_id, title, complaint_status, assigned_admin_username 
FROM core.vw_open_complaints WHERE complaint_id = @comp_id;

PRINT '--- SCENARIO 5 | STEP 3: Complaint is Resolved ---';
UPDATE core.complaints SET complaint_status = 'resolved', resolved_at = GETDATE() WHERE complaint_id = @comp_id;


SELECT 
    (SELECT COUNT(*) FROM core.vw_open_complaints WHERE complaint_id = @comp_id) AS Is_In_Open_View,
    complaint_status, resolved_at 
FROM core.complaints WHERE complaint_id = @comp_id;
GO