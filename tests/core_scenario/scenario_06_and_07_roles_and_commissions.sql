USE mini_snapp;
GO


PRINT '--- SCENARIO 6 | STEP 1: Check Permissions for Normal User ---';

SELECT username, role_name, permission_name 
FROM core.vw_user_roles_permissions 
WHERE username = 'wallet_demo'; 

PRINT '--- SCENARIO 6 | STEP 2: Check Permissions for Admin User ---';

SELECT username, role_name, permission_name 
FROM core.vw_user_roles_permissions 
WHERE username = 'future_admin' AND permission_name IS NOT NULL;



PRINT '--- SCENARIO 7 | STEP 1: Create Historical Commission Rates ---';

INSERT INTO core.commission_rates (service_type, driver_share, app_share, effective_from, effective_to)
VALUES ('taxi', 90.00, 10.00, DATEADD(MONTH, -6, GETDATE()), DATEADD(MONTH, -2, GETDATE()));

INSERT INTO core.commission_rates (service_type, driver_share, app_share, effective_from, effective_to)
VALUES ('taxi', 85.00, 15.00, DATEADD(MONTH, -2, GETDATE()), NULL); 

PRINT '--- SCENARIO 7 | STEP 2: Get Current Commission Rate ---';

SELECT service_type, driver_share, app_share, effective_from ,effective_to
FROM core.fn_get_active_commission_rate('taxi', NULL);

PRINT '--- SCENARIO 7 | STEP 3: Time Travel! Get Rate from 4 Months Ago ---';

DECLARE @past_date DATETIME = DATEADD(MONTH, -4, GETDATE());
SELECT service_type, driver_share, app_share,effective_from , effective_to 
FROM core.fn_get_active_commission_rate('taxi', @past_date);
GO