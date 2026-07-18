USE mini_snapp;
GO


PRINT '--- TAXI SCENARIO 1 | STEP 1: Register Core User as Driver ---';

DECLARE @driver_role_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'driver');
DECLARE @driver_uid INT;
EXEC core.sp_register_user 'demo_driver1', 'hash', 'Ali', 'Driver', '09201110001', NULL, @driver_role_id, @driver_uid OUTPUT;

PRINT '--- TAXI SCENARIO 1 | STEP 2: Register in Taxi Schema ---';

DECLARE @new_driver_id INT;
EXEC taxi.sp_register_driver 
    @user_id = @driver_uid, 
    @national_id = '1234567890', 
    @date_of_birth = '1990-01-01', 
    @gender = 'male', 
    @new_driver_id = @new_driver_id OUTPUT;


SELECT d.driver_id, d.national_id, d.driver_status, dw.balance AS taxi_wallet_balance
FROM taxi.drivers d 
JOIN taxi.driver_wallets dw ON d.driver_id = dw.driver_id
WHERE d.driver_id = @new_driver_id;



PRINT '--- TAXI SCENARIO 2 | STEP 1: Register Two Vehicles ---';
DECLARE @v1 INT, @v2 INT;

EXEC taxi.sp_register_vehicle @owner_id = @new_driver_id, @vehicle_type = 'economy', @license_plate = '11-A-111', @color = 'White', @model_name = 'Pride', @new_vehicle_id = @v1 OUTPUT;

EXEC taxi.sp_register_vehicle @owner_id = @new_driver_id, @vehicle_type = 'economy', @license_plate = '22-B-222', @color = 'Silver', @model_name = 'Tiba', @new_vehicle_id = @v2 OUTPUT;

PRINT '--- TAXI SCENARIO 2 | STEP 2: Check Active Vehicles Trigger ---';

SELECT vehicle_id, license_plate, model_name, is_active_now 
FROM taxi.vehicles 
WHERE owner_id = @new_driver_id;
GO