USE mini_snapp;
GO

IF NOT EXISTS (SELECT 1 FROM core.commission_rates WHERE service_type='taxi')
    INSERT INTO core.commission_rates (service_type, driver_share, app_share, effective_from) VALUES ('taxi', 80, 20, DATEADD(MONTH,-1,GETDATE()));
IF NOT EXISTS (SELECT 1 FROM taxi.pricing_parameters WHERE vehicle_type = 'economy' AND service_type = 'passenger')
    INSERT INTO taxi.pricing_parameters (vehicle_type, service_type, base_fare, price_per_km, price_per_minute) VALUES ('economy', 'passenger', 10.00, 2.00, 0.50);
IF NOT EXISTS (SELECT 1 FROM taxi.vehicle_type_services WHERE vehicle_type='economy')
    INSERT INTO taxi.vehicle_type_services (vehicle_type, service_type) VALUES ('economy', 'passenger');


DECLARE @cust_role INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @pass_uid INT;
EXEC core.sp_register_user 'demo_pass1', 'hash', 'Reza', 'Passenger', '09301110001', NULL, @cust_role, @pass_uid OUTPUT;
EXEC core.sp_charge_wallet @pass_uid, 100.00, 'card'; 


DECLARE @drv_id INT = (SELECT TOP 1 driver_id FROM taxi.drivers d JOIN core.users u ON d.user_id = u.user_id WHERE u.username = 'demo_driver1');
UPDATE taxi.drivers SET driver_status = 'available' WHERE driver_id = @drv_id;
INSERT INTO taxi.driver_locations (driver_id, latitude, longitude) VALUES (@drv_id, 35.7000, 51.4000);


PRINT '--- TAXI SCENARIO 3 | STEP 1: Create Ride Offer ---';
DECLARE @offer_id INT;

EXEC taxi.sp_create_ride_offer 
    @passenger_id = @pass_uid, 
    @origin_latitude = 35.7010, @origin_longitude = 51.4010, 
    @destination_latitude = 35.7500, @destination_longitude = 51.4500, 
    @vehicle_type = 'economy', @service_type = 'passenger', 
    @candidate_count = 5, @offer_ttl_minutes = 3, @is_prepaid = 0, @scheduled_start_time = NULL, 
    @new_offer_id = @offer_id OUTPUT;


SELECT ro.calculated_price, roc.driver_id, roc.response_status
FROM taxi.ride_offers ro 
JOIN taxi.ride_offer_candidates roc ON ro.ride_offer_id = roc.offer_id
WHERE ro.ride_offer_id = @offer_id;

PRINT '--- TAXI SCENARIO 3 | STEP 2: Driver Accepts the Offer ---';

DECLARE @ride_id INT;


DECLARE @actual_cand INT = (SELECT TOP 1 driver_id FROM taxi.ride_offer_candidates WHERE offer_id = @offer_id);

EXEC taxi.sp_respond_to_ride_offer @offer_id, @actual_cand, 'accepted', @ride_id OUTPUT;


SELECT ride_id, ride_status FROM taxi.rides WHERE ride_id = @ride_id;
SELECT driver_id, driver_status FROM taxi.drivers WHERE driver_id = @actual_cand;


PRINT '--- TAXI SCENARIO 4 | STEP 1: Start to Destination ---';

EXEC taxi.sp_start_ride_to_destination @ride_id;

SELECT ride_id, ride_status, started_at FROM taxi.rides WHERE ride_id = @ride_id;

PRINT '--- TAXI SCENARIO 4 | STEP 2: Complete Ride (Financials) ---';

SELECT 'Passenger_Core_Wallet' AS Target, balance FROM core.user_wallets WHERE user_id = @pass_uid
UNION ALL
SELECT 'Driver_Taxi_Wallet', balance FROM taxi.driver_wallets WHERE driver_id = @drv_id;

EXEC taxi.sp_complete_ride @ride_id, 'wallet';


SELECT 'Passenger_Core_Wallet' AS Target, balance FROM core.user_wallets WHERE user_id = @pass_uid
UNION ALL
SELECT 'Driver_Taxi_Wallet', balance FROM taxi.driver_wallets WHERE driver_id = @drv_id;

PRINT '--- TAXI SCENARIO 4 | STEP 3: Rate The Driver (Gamification) ---';

EXEC taxi.sp_rate_ride @ride_id, 'passenger', 5, 'Perfect and polite driver!';


SELECT average_rating, activity_points, rank_position 
FROM taxi.vw_driver_ranking WHERE driver_id = @drv_id;
GO