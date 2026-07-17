USE mini_snapp;
GO


PRINT '--- TAXI SCENARIO 9 | STEP 1: Setup Driver as Passenger ---';


DECLARE @drv_user_id INT = (SELECT user_id FROM core.users WHERE username = 'demo_driver1');
DECLARE @drv_taxi_id INT = (SELECT driver_id FROM taxi.drivers WHERE user_id = @drv_user_id);

EXEC core.sp_charge_wallet @drv_user_id, 50.00, 'card';


SELECT 'Core User Wallet (For Paying)' AS Wallet_Type, balance FROM core.user_wallets WHERE user_id = @drv_user_id
UNION ALL
SELECT 'Taxi Driver Wallet (For Earning)', balance FROM taxi.driver_wallets WHERE driver_id = @drv_taxi_id;


PRINT '--- TAXI SCENARIO 9 | STEP 2: Driver Requests a Ride ---';
DECLARE @dr_offer INT, @dr_ride INT;

EXEC taxi.sp_create_ride_offer 
    @passenger_id = @drv_user_id, 
    @origin_latitude = 35.1, @origin_longitude = 51.1, 
    @destination_latitude = 35.2, @destination_longitude = 51.2, 
    @vehicle_type = 'economy', @service_type = 'passenger', 
    @candidate_count = 1, @offer_ttl_minutes = 3, @is_prepaid = 0, @scheduled_start_time = NULL, 
    @new_offer_id = @dr_offer OUTPUT;


DECLARE @actual_driver INT = (SELECT TOP 1 driver_id FROM taxi.ride_offer_candidates WHERE offer_id = @dr_offer);


EXEC taxi.sp_respond_to_ride_offer @dr_offer, @actual_driver, 'accepted', @dr_ride OUTPUT;


EXEC taxi.sp_update_ride_status @dr_ride, 'to_destination', NULL;
EXEC taxi.sp_complete_ride @dr_ride, 'wallet';
PRINT '--- TAXI SCENARIO 9 | STEP 3: Verify Isolated Wallets ---';

SELECT 'Core User Wallet (After Ride)' AS Wallet_Type, balance FROM core.user_wallets WHERE user_id = @drv_user_id
UNION ALL
SELECT 'Taxi Driver Wallet (Unaffected)', balance FROM taxi.driver_wallets WHERE driver_id = @drv_taxi_id;
GO