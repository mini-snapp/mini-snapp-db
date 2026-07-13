USE mini_snapp;
GO

PRINT '=============================================';
PRINT 'STARTING TEST SUITE: taxi';
PRINT '=============================================';
GO

-- پاکسازی نتایج قبلی مختص تاکسی
DELETE FROM test.test_results WHERE test_suite = 'taxi';
GO

-- =============================================
-- 1. TESTING FUNCTIONS
-- =============================================
PRINT '--- Testing fn_vehicle_supports_service ---';
GO

DECLARE @economy_id INT = (SELECT TOP 1 vehicle_id FROM taxi.vehicles WHERE vehicle_type = 'economy');
DECLARE @motor_id INT = (SELECT TOP 1 vehicle_id FROM taxi.vehicles WHERE vehicle_type = 'motorcycle');

-- Economy supports passenger
DECLARE @actual_1 BIT = taxi.fn_vehicle_supports_service(@economy_id, 'passenger');
EXEC test.sp_assert_equals 'taxi', 'fn_vehicle_supports_service: economy supports passenger', 1, @actual_1;

-- Economy does NOT support cargo
DECLARE @actual_2 BIT = taxi.fn_vehicle_supports_service(@economy_id, 'cargo');
EXEC test.sp_assert_equals 'taxi', 'fn_vehicle_supports_service: economy does NOT support cargo', 0, @actual_2;

-- Motorcycle supports cargo
DECLARE @actual_3 BIT = taxi.fn_vehicle_supports_service(@motor_id, 'cargo');
EXEC test.sp_assert_equals 'taxi', 'fn_vehicle_supports_service: motorcycle supports cargo', 1, @actual_3;
GO

PRINT '--- Testing fn_calculate_ride_price ---';
GO
-- Economy Base: 15000, Per Km: 2000, Per Min: 500
-- For 5km and 10min -> 15000 + (5*2000) + (10*500) = 30000.00
DECLARE @calculated_price DECIMAL(10,2) = taxi.fn_calculate_ride_price('economy', 'passenger', 5.00, 10, NULL);
EXEC test.sp_assert_equals 'taxi', 'fn_calculate_ride_price: exact formula calculation', 30000.00, @calculated_price;
GO

PRINT '--- Testing fn_find_nearest_available_drivers ---';
GO
-- Coordinate near Sara's home: 35.7195, 51.4087
-- Amir is near (35.7196, 51.4088) and available. Kaveh is offline. Neda's active car is Premium.
-- Expecting Amir to be the only one returned for economy/passenger.
DECLARE @driver_count INT = (
    SELECT COUNT(*) FROM taxi.fn_find_nearest_available_drivers(35.7195, 51.4087, 'economy', 'passenger', 5)
);
EXEC test.sp_assert_equals 'taxi', 'fn_find_nearest_available_drivers: only online matching drivers returned', 1, @driver_count;

DECLARE @nearest_driver INT = (
    SELECT TOP 1 driver_id FROM taxi.fn_find_nearest_available_drivers(35.7195, 51.4087, 'economy', 'passenger', 5)
);
DECLARE @amir_id INT = (SELECT driver_id FROM taxi.drivers WHERE national_id = '0011223344');
EXEC test.sp_assert_equals 'taxi', 'fn_find_nearest_available_drivers: correct driver is prioritized', @amir_id, @nearest_driver;
GO

-- =============================================
-- 2. TESTING TRIGGERS (SINGLE ACTIVE VEHICLE)
-- =============================================
PRINT '--- Testing trg_vehicles_enforce_single_active ---';
GO
DECLARE @drv_neda INT = (SELECT driver_id FROM taxi.drivers WHERE national_id = '0022334455');
DECLARE @motorcycle_id INT = (SELECT vehicle_id FROM taxi.vehicles WHERE owner_id = @drv_neda AND vehicle_type = 'motorcycle');
DECLARE @premium_id INT = (SELECT vehicle_id FROM taxi.vehicles WHERE owner_id = @drv_neda AND vehicle_type = 'premium');

-- Neda currently has Premium active. We activate Motorcycle.
UPDATE taxi.vehicles SET is_active_now = 1 WHERE vehicle_id = @motorcycle_id;

DECLARE @premium_active BIT = (SELECT is_active_now FROM taxi.vehicles WHERE vehicle_id = @premium_id);
EXEC test.sp_assert_equals 'taxi', 'trg_vehicles_enforce_single_active: previous vehicle auto-deactivated', 0, @premium_active;

-- Revert for further tests
UPDATE taxi.vehicles SET is_active_now = 1 WHERE vehicle_id = @premium_id;
GO

-- =============================================
-- 3. TESTING CORE WORKFLOW & DECOUPLED PAYMENT
-- =============================================
PRINT '--- Testing Workflow: Prepaid Scheduled Ride (Food Simulation) ---';
GO
DECLARE @taha_id INT = (SELECT user_id FROM core.users WHERE username = 'newbie_taha');
DECLARE @amir_drv_id INT = (SELECT driver_id FROM taxi.drivers WHERE national_id = '0011223344');
DECLARE @new_offer_id INT;
DECLARE @scheduled_time DATETIME = DATEADD(MINUTE, 30, GETDATE());

-- 3.1 Create Prepaid Scheduled Offer
EXEC taxi.sp_create_ride_offer
    @passenger_id = @taha_id,
    @origin_latitude = 35.7195, @origin_longitude = 51.4087,
    @destination_latitude = 35.7300, @destination_longitude = 51.4255,
    @vehicle_type = 'economy', @service_type = 'passenger',
    @is_prepaid = 1, @scheduled_start_time = @scheduled_time,
    @new_offer_id = @new_offer_id OUTPUT;

EXEC test.sp_assert_not_null 'taxi', 'sp_create_ride_offer: offer created successfully', @new_offer_id;

-- 3.2 Respond to Offer (Accept)
DECLARE @new_ride_id INT;
EXEC taxi.sp_respond_to_ride_offer
    @offer_id = @new_offer_id, @driver_id = @amir_drv_id, @response = 'accepted',
    @new_ride_id = @new_ride_id OUTPUT;

EXEC test.sp_assert_not_null 'taxi', 'sp_respond_to_ride_offer: accepted and ride created', @new_ride_id;

-- 3.3 Check State mapping (Should be 'scheduled' and 'paid')
DECLARE @initial_state VARCHAR(20), @payment_state VARCHAR(20);
-- FIX: Changed payment_status to ride_payment_status
SELECT @initial_state = ride_status, @payment_state = ride_payment_status FROM taxi.rides WHERE ride_id = @new_ride_id;
EXEC test.sp_assert_equals 'taxi', 'State Machine: initial state is scheduled for future rides', 'scheduled', @initial_state;
EXEC test.sp_assert_equals 'taxi', 'Payment Mapping: is_prepaid=1 translates to ride_payment_status=paid', 'paid', @payment_state;

-- 3.4 Invalid Transitions Validation
BEGIN TRY
    EXEC taxi.sp_complete_ride @ride_id = @new_ride_id;
    EXEC test.sp_assert_true 'taxi', 'State Machine: prevent jumping from scheduled to completed', 0;
END TRY
BEGIN CATCH
    EXEC test.sp_assert_true 'taxi', 'State Machine: prevent jumping from scheduled to completed correctly raises error', 1;
END CATCH

-- 3.5 Proper State Transitions (scheduled -> to_origin -> to_destination -> completed)
EXEC taxi.sp_update_ride_status @new_ride_id, 'to_origin';
DECLARE @state1 VARCHAR(20) = (SELECT ride_status FROM taxi.rides WHERE ride_id = @new_ride_id);
EXEC test.sp_assert_equals 'taxi', 'State Machine: transitioned to to_origin', 'to_origin', @state1;

EXEC taxi.sp_start_ride_to_destination @new_ride_id;
DECLARE @state2 VARCHAR(20) = (SELECT ride_status FROM taxi.rides WHERE ride_id = @new_ride_id);
EXEC test.sp_assert_equals 'taxi', 'State Machine: transitioned to to_destination', 'to_destination', @state2;

-- 3.6 Complete Ride (Prepaid)
DECLARE @driver_balance_before DECIMAL(10,2) = (SELECT balance FROM taxi.driver_wallets WHERE driver_id = @amir_drv_id);

EXEC taxi.sp_complete_ride @ride_id = @new_ride_id;

DECLARE @driver_balance_after DECIMAL(10,2) = (SELECT balance FROM taxi.driver_wallets WHERE driver_id = @amir_drv_id);
DECLARE @driver_status VARCHAR(20) = (SELECT driver_status FROM taxi.drivers WHERE driver_id = @amir_drv_id);
DECLARE @flag BIT = (CASE WHEN @driver_balance_after > @driver_balance_before THEN 1 ELSE 0 END)
EXEC test.sp_assert_true 'taxi', 'sp_complete_ride: driver wallet increased without double-charging passenger', 
        @flag;
EXEC test.sp_assert_equals 'taxi', 'sp_complete_ride: driver status returned to available', 'available', @driver_status;
GO

-- =============================================
-- 4. TESTING CANCELLATION & REFUNDS
-- =============================================
PRINT '--- Testing Workflow: Cancellation and Refund ---';
GO
DECLARE @taha_id INT = (SELECT user_id FROM core.users WHERE username = 'newbie_taha');
DECLARE @amir_drv_id INT = (SELECT driver_id FROM taxi.drivers WHERE national_id = '0011223344');
DECLARE @cancel_offer_id INT;
DECLARE @cancel_ride_id INT;

-- Setup: Create and Accept a Prepaid Ride
EXEC taxi.sp_create_ride_offer
    @passenger_id = @taha_id, @origin_latitude = 35.7195, @origin_longitude = 51.4087,
    @destination_latitude = 35.7300, @destination_longitude = 51.4255,
    @vehicle_type = 'economy', @service_type = 'passenger', @is_prepaid = 1,
    @new_offer_id = @cancel_offer_id OUTPUT;

EXEC taxi.sp_respond_to_ride_offer
    @offer_id = @cancel_offer_id, @driver_id = @amir_drv_id, @response = 'accepted',
    @new_ride_id = @cancel_ride_id OUTPUT;

DECLARE @passenger_balance_before DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @taha_id);

-- Action: Cancel the ride
EXEC taxi.sp_cancel_ride @ride_id = @cancel_ride_id, @cancel_reason = 'driver_requested';

-- Assertions
DECLARE @passenger_balance_after DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @taha_id);
-- FIX: Changed payment_status to ride_payment_status
DECLARE @pay_status VARCHAR(20) = (SELECT ride_payment_status FROM taxi.rides WHERE ride_id = @cancel_ride_id);
DECLARE @ride_status VARCHAR(20) = (SELECT ride_status FROM taxi.rides WHERE ride_id = @cancel_ride_id);

DECLARE @flag BIT = (CASE WHEN @passenger_balance_after > @passenger_balance_before THEN 1 ELSE 0 END);
EXEC test.sp_assert_true 'taxi', 'sp_cancel_ride: wallet refunded for prepaid ride', 
        @flag;
EXEC test.sp_assert_equals 'taxi', 'sp_cancel_ride: payment status updated to refunded', 'refunded', @pay_status;
EXEC test.sp_assert_equals 'taxi', 'sp_cancel_ride: ride status updated to cancelled', 'cancelled', @ride_status;
GO

-- =============================================
-- 5. TESTING RATINGS & METRICS TRIGGER (REFINED)
-- =============================================
PRINT '--- Testing Rating System ---';
GO

-- اطمینان از وجود یک سفر تکمیل شده برای تست
DECLARE @completed_ride_id INT = (SELECT TOP 1 ride_id FROM taxi.rides WHERE ride_status = 'completed');

IF @completed_ride_id IS NULL
BEGIN
    PRINT 'No completed ride found, skipping complex rating tests.';
END
ELSE
BEGIN
    -- Valid Rating
    EXEC taxi.sp_rate_ride @ride_id = @completed_ride_id, @rater_role = 'passenger', @rating = 4, @comment = 'Good ride';

    DECLARE @rating_val INT = (SELECT passenger_rating_to_driver FROM taxi.rides WHERE ride_id = @completed_ride_id);
    EXEC test.sp_assert_equals 'taxi', 'sp_rate_ride: passenger rating recorded successfully', 4, @rating_val;

    -- Double Rating Protection
    BEGIN TRY
        EXEC taxi.sp_rate_ride @ride_id = @completed_ride_id, @rater_role = 'passenger', @rating = 5;
        EXEC test.sp_assert_equals 'taxi', 'sp_rate_ride: double rating should raise error', 1, 0; -- Should not reach here
    END TRY
    BEGIN CATCH
        EXEC test.sp_assert_true 'taxi', 'sp_rate_ride: double rating correctly raises error', 1;
    END CATCH
END

-- Out of Bounds Protection (Test with dummy or existing)
BEGIN TRY
    EXEC taxi.sp_rate_ride @ride_id = -1, @rater_role = 'driver', @rating = 6;
    EXEC test.sp_assert_equals 'taxi', 'sp_rate_ride: invalid rating bounds should raise error', 1, 0;
END TRY
BEGIN CATCH
    EXEC test.sp_assert_true 'taxi', 'sp_rate_ride: invalid rating bounds correctly raises error', 1;
END CATCH
GO
-- =============================================
-- SUMMARY
-- =============================================
EXEC test.sp_print_summary @test_suite = 'taxi';
GO