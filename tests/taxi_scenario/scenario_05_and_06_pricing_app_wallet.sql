USE mini_snapp;
GO


PRINT '--- TAXI SCENARIO 5 | STEP 1: Ensure Premium Pricing Exists ---';

IF NOT EXISTS (SELECT 1 FROM taxi.pricing_parameters WHERE vehicle_type = 'premium')
BEGIN
    INSERT INTO taxi.vehicle_type_services (vehicle_type, service_type) VALUES ('premium', 'passenger');
 
    INSERT INTO taxi.pricing_parameters (vehicle_type, service_type, base_fare, price_per_km, price_per_minute) 
    VALUES ('premium', 'passenger', 25.00, 4.00, 1.00); 
END

PRINT '--- TAXI SCENARIO 5 | STEP 2: Compare Prices ---';

DECLARE @eco_price DECIMAL(10,2) = taxi.fn_calculate_ride_price('economy', 'passenger', 10.0, 20, GETDATE());
DECLARE @vip_price DECIMAL(10,2) = taxi.fn_calculate_ride_price('premium', 'passenger', 10.0, 20, GETDATE());


SELECT 
    'Economy (Standard)' AS Vehicle_Type, 
    '10 km' AS Distance, 
    '20 mins' AS Duration, 
    @eco_price AS Calculated_Price
UNION ALL
SELECT 
    'Premium (VIP)', '10 km', '20 mins', @vip_price;



PRINT '--- TAXI SCENARIO 6 | STEP 1: Check App Wallet Before Ride ---';

DECLARE @app_wallet_before DECIMAL(10,2) = (SELECT TOP 1 total_balance FROM core.app_wallets);
SELECT @app_wallet_before AS App_Company_Balance_Before;

PRINT '--- TAXI SCENARIO 6 | STEP 2: Complete a Quick Ride ---';

DECLARE @dummy_pass INT = (SELECT TOP 1 user_id FROM core.users WHERE username = 'demo_pass1');
DECLARE @quick_offer INT, @quick_ride INT;


EXEC taxi.sp_create_ride_offer 
    @passenger_id = @dummy_pass, 
    @origin_latitude = 35.1, @origin_longitude = 51.1, 
    @destination_latitude = 35.2, @destination_longitude = 51.2, 
    @vehicle_type = 'economy', @service_type = 'passenger', 
    @candidate_count = 1, @offer_ttl_minutes = 3, @is_prepaid = 0, @scheduled_start_time = NULL, 
    @new_offer_id = @quick_offer OUTPUT;


DECLARE @actual_candidate_drv INT = (SELECT TOP 1 driver_id FROM taxi.ride_offer_candidates WHERE offer_id = @quick_offer);

EXEC taxi.sp_respond_to_ride_offer @quick_offer, @actual_candidate_drv, 'accepted', @quick_ride OUTPUT;


EXEC taxi.sp_update_ride_status @quick_ride, 'to_destination', NULL;
EXEC taxi.sp_complete_ride @quick_ride, 'wallet';
PRINT '--- TAXI SCENARIO 6 | STEP 3: Check App Wallet After Ride ---';

DECLARE @app_wallet_after DECIMAL(10,2) = (SELECT TOP 1 total_balance FROM core.app_wallets);
DECLARE @ride_cost DECIMAL(10,2) = (SELECT calculated_price FROM taxi.rides WHERE ride_id = @quick_ride);

SELECT 
    @ride_cost AS Total_Ride_Price,
    @app_wallet_before AS Company_Balance_Before,
    @app_wallet_after AS Company_Balance_After,
    (@app_wallet_after - @app_wallet_before) AS Profit_Earned_From_This_Ride;
GO