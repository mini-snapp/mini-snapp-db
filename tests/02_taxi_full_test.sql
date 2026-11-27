USE mini_snapp;
GO
SET NOCOUNT ON;
GO

-- =============================================
-- AUTOMATED TEST SUITE 02: TAXI SCHEMA
-- Prerequisite: tests/00_test_framework.sql
-- =============================================

EXEC test.sp_reset_all_data;
DELETE FROM test.test_results WHERE test_suite = 'taxi';
GO

-- PHASE 1: SEED ISOLATED TAXI TEST FIXTURES (USD)

INSERT INTO core.roles (role_name, role_description, hierarchy_level) VALUES
('customer', 'Customer', 1),
('driver',   'Driver',   2);

DECLARE @rc INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @rd INT = (SELECT role_id FROM core.roles WHERE role_name = 'driver');

INSERT INTO core.app_wallets (total_balance) VALUES (0.00);

INSERT INTO core.commission_rates (service_type, driver_share, app_share, effective_from)
VALUES ('taxi', 80.00, 20.00, DATEADD(MONTH, -1, GETDATE()));

INSERT INTO core.users (username, password_hash, registration_phone, role_id) VALUES
('passenger_test', 'hash1', '09100000001', @rc),
('poor_passenger', 'hash4', '09100000002', @rc),
('driver_test_1',  'hash2', '09200000001', @rd),
('driver_test_2',  'hash3', '09200000002', @rd);

INSERT INTO core.user_wallets (user_id, balance)
SELECT user_id,
    CASE username
        WHEN 'passenger_test' THEN 200.00
        WHEN 'poor_passenger' THEN   2.00
        ELSE 0.00
    END
FROM core.users;

INSERT INTO taxi.vehicle_type_services (vehicle_type, service_type) VALUES
('economy',    'passenger'),
('motorcycle', 'cargo');

INSERT INTO taxi.pricing_parameters (vehicle_type, service_type, base_fare, price_per_km, price_per_minute) VALUES
('economy', 'passenger', 10.00, 2.00, 0.50);

DECLARE @d1_uid INT = (SELECT user_id FROM core.users WHERE username = 'driver_test_1');
INSERT INTO taxi.drivers (user_id, national_id, date_of_birth, driver_status)
VALUES (@d1_uid, '1111111111', '1990-01-01', 'available');
DECLARE @d1_id INT = SCOPE_IDENTITY();
INSERT INTO taxi.driver_wallets (driver_id, balance) VALUES (@d1_id, 0.00);
INSERT INTO taxi.vehicles (owner_id, vehicle_type, license_plate, color, model_name, is_active_now)
VALUES (@d1_id, 'economy', '11A11111', 'White', 'Peugeot 206', 1);
INSERT INTO taxi.driver_locations (driver_id, latitude, longitude, updated_at)
VALUES (@d1_id, 35.70000000, 51.40000000, GETDATE());

DECLARE @d2_uid INT = (SELECT user_id FROM core.users WHERE username = 'driver_test_2');
INSERT INTO taxi.drivers (user_id, national_id, date_of_birth, driver_status)
VALUES (@d2_uid, '2222222222', '1990-01-01', 'busy');
DECLARE @d2_id INT = SCOPE_IDENTITY();
INSERT INTO taxi.driver_wallets (driver_id, balance) VALUES (@d2_id, 0.00);
INSERT INTO taxi.vehicles (owner_id, vehicle_type, license_plate, color, model_name, is_active_now)
VALUES (@d2_id, 'economy', '22B22222', 'Silver', 'Samand', 1);
INSERT INTO taxi.driver_locations (driver_id, latitude, longitude, updated_at)
VALUES (@d2_id, 35.70050000, 51.40050000, GETDATE());
GO

-- PHASE 2: EXECUTE TAXI TESTS

PRINT '=============================================';
PRINT 'STARTING TEST SUITE: taxi';
PRINT '=============================================';
GO

-- Test 1: Pricing & Fleet Constraints
PRINT '--- Testing Pricing & Vehicle Triggers ---';

DECLARE @calc_price DECIMAL(10,2) = taxi.fn_calculate_ride_price('economy', 'passenger', 5.0, 10, NULL);
EXEC test.sp_assert_equals 'taxi', 'fn_calculate_ride_price: $10 + (5km * $2) + (10min * $0.50) = $25.00', 25.00, @calc_price;

DECLARE @v1_id INT = (SELECT vehicle_id FROM taxi.vehicles WHERE license_plate = '11A11111');
DECLARE @service_support BIT = taxi.fn_vehicle_supports_service(@v1_id, 'passenger');
EXEC test.sp_assert_equals 'taxi', 'fn_vehicle_supports_service: economy supports passenger', 1, @service_support;

DECLARE @d1_id INT = (SELECT driver_id FROM taxi.drivers WHERE national_id = '1111111111');
DECLARE @v_new INT;
EXEC taxi.sp_register_vehicle @d1_id, 'economy', '11C33333', 'Black', 'Cerato', @v_new OUTPUT;
DECLARE @old_active BIT = (SELECT is_active_now FROM taxi.vehicles WHERE vehicle_id = @v1_id);
EXEC test.sp_assert_equals 'taxi', 'trg_vehicles_enforce_single_active: deactivates previous vehicle automatically', 0, @old_active;
GO

-- Test 2: Dispatch Flow & State Machine
PRINT '--- Testing Dispatch & Ride State Machine ---';

DECLARE @pass_uid INT = (SELECT user_id FROM core.users WHERE username = 'passenger_test');
DECLARE @d1_id INT = (SELECT driver_id FROM taxi.drivers WHERE national_id = '1111111111');
DECLARE @offer_id INT;

EXEC taxi.sp_create_ride_offer
    @passenger_id = @pass_uid,
    @origin_latitude = 35.70100000, @origin_longitude = 51.40100000,
    @destination_latitude = 35.75000000, @destination_longitude = 51.45000000,
    @vehicle_type = 'economy', @service_type = 'passenger',
    @candidate_count = 5, @offer_ttl_minutes = 3, @is_prepaid = 0, @scheduled_start_time = NULL,
    @new_offer_id = @offer_id OUTPUT;

EXEC test.sp_assert_not_null 'taxi', 'sp_create_ride_offer: creates offer successfully', @offer_id;

DECLARE @cand_count INT = (SELECT COUNT(*) FROM taxi.ride_offer_candidates WHERE offer_id = @offer_id);
EXEC test.sp_assert_equals 'taxi', 'fn_find_nearest_available_drivers: selects only available driver (excludes busy)', 1, @cand_count;

DECLARE @ride_id INT;
EXEC taxi.sp_respond_to_ride_offer @offer_id, @d1_id, 'accepted', @ride_id OUTPUT;
EXEC test.sp_assert_not_null 'taxi', 'sp_respond_to_ride_offer: accepting offer creates ride', @ride_id;

DECLARE @ride_status VARCHAR(20) = (SELECT ride_status FROM taxi.rides WHERE ride_id = @ride_id);
EXEC test.sp_assert_equals 'taxi', 'sp_respond_to_ride_offer: sets initial status to to_origin', 'to_origin', @ride_status;

DECLARE @d1_status VARCHAR(20) = (SELECT driver_status FROM taxi.drivers WHERE driver_id = @d1_id);
EXEC test.sp_assert_equals 'taxi', 'sp_respond_to_ride_offer: marks driver as busy', 'busy', @d1_status;

DECLARE @invalid_jump_blocked BIT = 0;
BEGIN TRY
    EXEC taxi.sp_update_ride_status @ride_id, 'completed', NULL;
END TRY
BEGIN CATCH
    SET @invalid_jump_blocked = 1;
END CATCH
EXEC test.sp_assert_true 'taxi', 'sp_update_ride_status: blocks invalid jump from to_origin directly to completed', @invalid_jump_blocked;
GO

-- Test 3: Ride Completion & Commission Split
PRINT '--- Testing Ride Settlement & Commission Split ---';

DECLARE @ride_id INT = (SELECT TOP 1 ride_id FROM taxi.rides ORDER BY ride_id DESC);
DECLARE @pass_uid INT = (SELECT passenger_id FROM taxi.rides WHERE ride_id = @ride_id);
DECLARE @d1_id INT = (SELECT driver_id FROM taxi.rides WHERE ride_id = @ride_id);

EXEC taxi.sp_update_ride_status @ride_id, 'to_destination', NULL;
EXEC taxi.sp_complete_ride @ride_id, 'wallet';

DECLARE @final_status VARCHAR(20) = (SELECT ride_status FROM taxi.rides WHERE ride_id = @ride_id);
EXEC test.sp_assert_equals 'taxi', 'sp_complete_ride: transitions status to completed', 'completed', @final_status;

DECLARE @ride_price DECIMAL(10,2) = (SELECT calculated_price FROM taxi.rides WHERE ride_id = @ride_id);
DECLARE @driver_expected DECIMAL(10,2) = ROUND(@ride_price * 0.80, 2);
DECLARE @app_expected DECIMAL(10,2) = ROUND(@ride_price * 0.20, 2);
DECLARE @pass_expected DECIMAL(10,2) = 200.00 - @ride_price;

DECLARE @driver_actual DECIMAL(10,2) = (SELECT balance FROM taxi.driver_wallets WHERE driver_id = @d1_id);
DECLARE @app_actual DECIMAL(10,2) = (SELECT TOP 1 total_balance FROM core.app_wallets);
DECLARE @pass_actual DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @pass_uid);

EXEC test.sp_assert_equals 'taxi', 'sp_complete_ride: credits 80% share to driver wallet', @driver_expected, @driver_actual;
EXEC test.sp_assert_equals 'taxi', 'sp_complete_ride: credits 20% share to platform app_wallet', @app_expected, @app_actual;
EXEC test.sp_assert_equals 'taxi', 'sp_complete_ride: deducts fare from passenger wallet', @pass_expected, @pass_actual;

DECLARE @d1_after VARCHAR(20) = (SELECT driver_status FROM taxi.drivers WHERE driver_id = @d1_id);
EXEC test.sp_assert_equals 'taxi', 'sp_complete_ride: releases driver back to available', 'available', @d1_after;
GO

-- Test 4: Prepaid Scheduled Ride, Escrow Deduction & Full Cancellation Refund
PRINT '--- Testing Prepaid Escrow & Cancellation Refund ---';

DECLARE @pass_uid INT = (SELECT user_id FROM core.users WHERE username = 'passenger_test');
DECLARE @poor_uid INT = (SELECT user_id FROM core.users WHERE username = 'poor_passenger');
DECLARE @d1_id INT = (SELECT driver_id FROM taxi.drivers WHERE national_id = '1111111111');
DECLARE @bal_before DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @pass_uid);

DECLARE @prepaid_offer INT, @prepaid_ride INT;
DECLARE @tomorrow DATETIME = DATEADD(DAY, 1, GETDATE());

EXEC taxi.sp_create_ride_offer
    @passenger_id = @pass_uid,
    @origin_latitude = 35.70100000, @origin_longitude = 51.40100000,
    @destination_latitude = 35.72000000, @destination_longitude = 51.42000000,
    @vehicle_type = 'economy', @service_type = 'passenger',
    @candidate_count = 5, @offer_ttl_minutes = 5, @is_prepaid = 1, @scheduled_start_time = @tomorrow,
    @new_offer_id = @prepaid_offer OUTPUT;

EXEC taxi.sp_respond_to_ride_offer @prepaid_offer, @d1_id, 'accepted', @prepaid_ride OUTPUT;

DECLARE @prepaid_price DECIMAL(10,2) = (SELECT calculated_price FROM taxi.rides WHERE ride_id = @prepaid_ride);
DECLARE @bal_expected_during DECIMAL(10,2) = @bal_before - @prepaid_price;
DECLARE @bal_during DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @pass_uid);
EXEC test.sp_assert_equals 'taxi', 'sp_respond_to_ride_offer (prepaid): deducts fare upfront on accept', @bal_expected_during, @bal_during;

EXEC taxi.sp_cancel_ride @prepaid_ride, 'Passenger changed plans';
DECLARE @bal_after_refund DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @pass_uid);
DECLARE @pay_status_after VARCHAR(20) = (SELECT ride_payment_status FROM taxi.rides WHERE ride_id = @prepaid_ride);
EXEC test.sp_assert_equals 'taxi', 'sp_cancel_ride: restores exact prepaid balance on cancellation', @bal_before, @bal_after_refund;
EXEC test.sp_assert_equals 'taxi', 'sp_cancel_ride: marks ride_payment_status as refunded', 'refunded', @pay_status_after;

-- Insufficient wallet balance check
DECLARE @poor_offer INT, @poor_ride INT, @insufficient_blocked BIT = 0;
EXEC taxi.sp_create_ride_offer
    @passenger_id = @poor_uid,
    @origin_latitude = 35.70100000, @origin_longitude = 51.40100000,
    @destination_latitude = 35.75000000, @destination_longitude = 51.45000000,
    @vehicle_type = 'economy', @service_type = 'passenger',
    @candidate_count = 5, @offer_ttl_minutes = 5, @is_prepaid = 1, @scheduled_start_time = NULL,
    @new_offer_id = @poor_offer OUTPUT;

BEGIN TRY
    EXEC taxi.sp_respond_to_ride_offer @poor_offer, @d1_id, 'accepted', @poor_ride OUTPUT;
END TRY
BEGIN CATCH
    SET @insufficient_blocked = 1;
END CATCH
EXEC test.sp_assert_true 'taxi', 'sp_pay_for_ride: rejects wallet payment when balance is insufficient', @insufficient_blocked;
GO

-- Test 5: Rating & Gamification Metrics
PRINT '--- Testing Rating & Audit Logs ---';

DECLARE @completed_ride_id INT = (SELECT TOP 1 ride_id FROM taxi.rides WHERE ride_status = 'completed' ORDER BY ride_id ASC);
DECLARE @d1_id INT = (SELECT driver_id FROM taxi.rides WHERE ride_id = @completed_ride_id);

EXEC taxi.sp_rate_ride @completed_ride_id, 'passenger', 5, 'Smooth ride!';
DECLARE @d1_avg DECIMAL(3,2) = (SELECT average_rating FROM taxi.drivers WHERE driver_id = @d1_id);
EXEC test.sp_assert_equals 'taxi', 'trg_rides_update_metrics: updates driver average_rating to 5.00', 5.00, @d1_avg;

DECLARE @log_schema VARCHAR(10) = (SELECT TOP 1 schema_name FROM taxi.taxi_logs ORDER BY taxi_log_id DESC);
EXEC test.sp_assert_equals 'taxi', 'sp_write_log: logs operations under schema "taxi"', 'taxi', @log_schema;
GO

EXEC test.sp_print_summary @test_suite = 'taxi';
EXEC test.sp_reset_all_data;
GO
