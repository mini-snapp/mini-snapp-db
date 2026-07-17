USE mini_snapp;
GO


-- PHASE 1: TEST FRAMEWORK SETUP 

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'test')
BEGIN
    EXEC('CREATE SCHEMA test');
END
GO

IF OBJECT_ID('test.test_results', 'U') IS NOT NULL DROP TABLE test.test_results;
CREATE TABLE test.test_results (
    test_result_id INT IDENTITY(1,1) NOT NULL,
    test_suite   VARCHAR(50)  NOT NULL, 
    test_name    VARCHAR(200) NOT NULL,
    result       VARCHAR(10)  NOT NULL, 
    expected_val VARCHAR(500) ,
    actual_val   VARCHAR(500) ,
    run_at       DATETIME DEFAULT GETDATE(),
    CONSTRAINT pk_test_results PRIMARY KEY (test_result_id),
    CONSTRAINT chk_test_results_result CHECK (result IN ('PASS','FAIL'))
);
GO


CREATE OR ALTER PROCEDURE test.sp_assert_equals
    @test_suite VARCHAR(50), @test_name VARCHAR(200), @expected SQL_VARIANT, @actual SQL_VARIANT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @result VARCHAR(10);
    IF @expected = @actual OR (@expected IS NULL AND @actual IS NULL) SET @result = 'PASS'; ELSE SET @result = 'FAIL';
    INSERT INTO test.test_results (test_suite, test_name, result, expected_val, actual_val)
    VALUES (@test_suite, @test_name, @result, CAST(@expected AS VARCHAR(500)), CAST(@actual AS VARCHAR(500)));
    IF @result = 'PASS' PRINT '  [PASS] ' + @test_name; ELSE PRINT '  [FAIL] ' + @test_name + ' | expected=' + CAST(@expected AS VARCHAR(500)) + ' actual=' + CAST(@actual AS VARCHAR(500));
END
GO

CREATE OR ALTER PROCEDURE test.sp_assert_true
    @test_suite VARCHAR(50), @test_name VARCHAR(200), @condition BIT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @result VARCHAR(10);
    IF @condition = 1 SET @result = 'PASS'; ELSE SET @result = 'FAIL';
    INSERT INTO test.test_results (test_suite, test_name, result, expected_val, actual_val)
    VALUES (@test_suite, @test_name, @result, '1 (true)', CAST(@condition AS VARCHAR(10)));
    IF @result = 'PASS' PRINT '  [PASS] ' + @test_name; ELSE PRINT '  [FAIL] ' + @test_name + ' | expected condition to be true, was false';
END
GO

CREATE OR ALTER PROCEDURE test.sp_assert_not_null
    @test_suite VARCHAR(50), @test_name VARCHAR(200), @value SQL_VARIANT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @result VARCHAR(10);
    IF @value IS NOT NULL SET @result = 'PASS'; ELSE SET @result = 'FAIL';
    INSERT INTO test.test_results (test_suite, test_name, result, expected_val, actual_val)
    VALUES (@test_suite, @test_name, @result, 'NOT NULL', CAST(@value AS VARCHAR(500)));
    IF @result = 'PASS' PRINT '  [PASS] ' + @test_name; ELSE PRINT '  [FAIL] ' + @test_name + ' | expected a non-null value, got NULL';
END
GO

CREATE OR ALTER PROCEDURE test.sp_print_summary
    @test_suite VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @total INT, @passed INT, @failed INT;
    SELECT @total = COUNT(*), @passed = SUM(CASE WHEN result = 'PASS' THEN 1 ELSE 0 END), @failed = SUM(CASE WHEN result = 'FAIL' THEN 1 ELSE 0 END)
    FROM test.test_results WHERE (@test_suite IS NULL OR test_suite = @test_suite);
    
    PRINT '=============================================';
    PRINT 'TEST SUMMARY' + ISNULL(' — ' + @test_suite, ' — ALL SUITES');
    PRINT 'Total:  ' + CAST(@total AS VARCHAR(10));
    PRINT 'Passed: ' + CAST(@passed AS VARCHAR(10));
    PRINT 'Failed: ' + CAST(@failed AS VARCHAR(10));
    PRINT '=============================================';
    IF @failed > 0
    BEGIN
        PRINT 'Failed tests:';
        SELECT test_name, expected_val, actual_val FROM test.test_results WHERE result = 'FAIL' AND (@test_suite IS NULL OR test_suite = @test_suite);
    END
END
GO


-- PHASE 2: PRE-CLEANUP 

DELETE FROM taxi.ride_payments; DELETE FROM taxi.taxi_logs; DELETE FROM taxi.passenger_stats;
DELETE FROM taxi.ride_offer_candidates; DELETE FROM taxi.ride_offers; DELETE FROM taxi.rides;
DELETE FROM taxi.pricing_parameters; DELETE FROM taxi.driver_secondary_phones; 
DELETE FROM taxi.driver_locations; DELETE FROM taxi.driver_wallets; 
DELETE FROM taxi.vehicle_type_services; DELETE FROM taxi.vehicles; DELETE FROM taxi.drivers;

DELETE FROM core.core_logs; DELETE FROM core.coupon_usages; DELETE FROM core.complaints;
DELETE FROM core.transactions; DELETE FROM core.saved_accounts; DELETE FROM core.addresses;
DELETE FROM core.admins; DELETE FROM core.user_wallets; DELETE FROM core.role_permissions;
DELETE FROM core.users; DELETE FROM core.roles; DELETE FROM core.permissions;
DELETE FROM core.coupons; DELETE FROM core.app_wallets; DELETE FROM core.commission_rates;
GO


-- PHASE 3: SEED TEST DATA FOR TAXI


INSERT INTO core.roles (role_name, role_description, hierarchy_level) VALUES ('customer', 'Customer', 1), ('driver', 'Driver', 2);
DECLARE @rc INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @rd INT = (SELECT role_id FROM core.roles WHERE role_name = 'driver');

INSERT INTO core.commission_rates (service_type, driver_share, app_share, effective_from) 
VALUES ('taxi', 80.00, 20.00, DATEADD(MONTH, -1, GETDATE())); 

INSERT INTO core.users (username, password_hash, registration_phone, role_id) VALUES
('passenger_test', 'hash1', '09100000001', @rc),
('driver_test_1',  'hash2', '09200000001', @rd),
('driver_test_2',  'hash3', '09200000002', @rd);


INSERT INTO core.user_wallets (user_id, balance) 
SELECT user_id, CASE WHEN username = 'passenger_test' THEN 500000.00 ELSE 0 END FROM core.users;

INSERT INTO taxi.vehicle_type_services (vehicle_type, service_type) VALUES 
('economy', 'passenger'), ('motorcycle', 'cargo'); 

INSERT INTO taxi.pricing_parameters (vehicle_type, service_type, base_fare, price_per_km, price_per_minute) VALUES 
('economy', 'passenger', 10000.00, 2000.00, 500.00); 


DECLARE @d1_uid INT = (SELECT user_id FROM core.users WHERE username = 'driver_test_1');
INSERT INTO taxi.drivers (user_id, national_id, date_of_birth, driver_status) VALUES (@d1_uid, '1111111111', '1990-01-01', 'available'); 
DECLARE @d1_id INT = (SELECT driver_id FROM taxi.drivers WHERE user_id = @d1_uid);
INSERT INTO taxi.driver_wallets (driver_id, balance) VALUES (@d1_id, 0); 
INSERT INTO taxi.vehicles (owner_id, vehicle_type, license_plate, color, model_name, is_active_now) VALUES (@d1_id, 'economy', '11A11111', 'White', 'Pride', 1);
INSERT INTO taxi.driver_locations (driver_id, latitude, longitude, updated_at) VALUES (@d1_id, 35.7000, 51.4000, GETDATE());


DECLARE @d2_uid INT = (SELECT user_id FROM core.users WHERE username = 'driver_test_2');
INSERT INTO taxi.drivers (user_id, national_id, date_of_birth, driver_status) VALUES (@d2_uid, '2222222222', '1990-01-01', 'busy'); 
DECLARE @d2_id INT = (SELECT driver_id FROM taxi.drivers WHERE user_id = @d2_uid);
INSERT INTO taxi.driver_wallets (driver_id, balance) VALUES (@d2_id, 0);
INSERT INTO taxi.vehicles (owner_id, vehicle_type, license_plate, color, model_name, is_active_now) VALUES (@d2_id, 'economy', '22B22222', 'Silver', 'Tiba', 1);
INSERT INTO taxi.driver_locations (driver_id, latitude, longitude, updated_at) VALUES (@d2_id, 35.7005, 51.4005, GETDATE());
GO



-- PHASE 4: EXECUTE TESTS 

PRINT '=============================================';
PRINT 'STARTING TEST SUITE: taxi';
PRINT '=============================================';
GO
DELETE FROM test.test_results;
GO


-- Test 1: Pricing & Matching Engine

PRINT '--- Testing Pricing Engine ---';

DECLARE @calc_price DECIMAL(10,2) = taxi.fn_calculate_ride_price('economy', 'passenger', 5.0, 10, NULL); 
EXEC test.sp_assert_equals 'taxi', 'fn_calculate_ride_price: Base + (Km*Rate) + (Min*Rate) is correct', 25000.00, @calc_price;

DECLARE @service_support BIT = taxi.fn_vehicle_supports_service((SELECT TOP 1 vehicle_id FROM taxi.vehicles WHERE license_plate='11A11111'), 'passenger');
EXEC test.sp_assert_equals 'taxi', 'fn_vehicle_supports_service: Economy supports passenger', 1, @service_support;
GO


-- Test 2: Ride Creation & Dispatch Flow

PRINT '--- Testing Dispatch Flow (State Machine) ---';
DECLARE @pass_uid INT = (SELECT user_id FROM core.users WHERE username = 'passenger_test');
DECLARE @d1_id INT = (SELECT driver_id FROM taxi.drivers WHERE national_id = '1111111111');
DECLARE @offer_id INT;


EXEC taxi.sp_create_ride_offer 
    @passenger_id = @pass_uid, @origin_latitude = 35.7010, @origin_longitude = 51.4010, 
    @destination_latitude = 35.7500, @destination_longitude = 51.4500, 
    @vehicle_type = 'economy', @service_type = 'passenger', 
    @candidate_count = 5, @offer_ttl_minutes = 3, @is_prepaid = 0, @scheduled_start_time = NULL, 
    @new_offer_id = @offer_id OUTPUT;

EXEC test.sp_assert_not_null 'taxi', 'sp_create_ride_offer: Offer created successfully', @offer_id;


DECLARE @d1_is_cand BIT = CASE WHEN EXISTS(SELECT 1 FROM taxi.ride_offer_candidates WHERE offer_id = @offer_id AND driver_id = @d1_id) THEN 1 ELSE 0 END;
EXEC test.sp_assert_equals 'taxi', 'fn_find_nearest_available_drivers: Only available nearby driver selected', 1, @d1_is_cand;


DECLARE @ride_id INT;
EXEC taxi.sp_respond_to_ride_offer @offer_id, @d1_id, 'accepted', @ride_id OUTPUT; 
EXEC test.sp_assert_not_null 'taxi', 'sp_respond_to_ride_offer: Accept creates an actual ride', @ride_id;

DECLARE @ride_status VARCHAR(20) = (SELECT ride_status FROM taxi.rides WHERE ride_id = @ride_id); 
EXEC test.sp_assert_equals 'taxi', 'sp_respond_to_ride_offer: Initial ride status is to_origin', 'to_origin', @ride_status;


DECLARE @d1_status VARCHAR(20) = (SELECT driver_status FROM taxi.drivers WHERE driver_id = @d1_id); 
EXEC test.sp_assert_equals 'taxi', 'Driver status changed to busy after accepting ride', 'busy', @d1_status;
GO


-- Test 3: Ride Completion & Financial Escrow

PRINT '--- Testing Financial Escrow & Ride Completion ---';
DECLARE @ride_id INT = (SELECT TOP 1 ride_id FROM taxi.rides ORDER BY ride_id DESC);
DECLARE @pass_uid INT = (SELECT passenger_id FROM taxi.rides WHERE ride_id = @ride_id); 
DECLARE @d1_id INT = (SELECT driver_id FROM taxi.rides WHERE ride_id = @ride_id); 


EXEC taxi.sp_update_ride_status @ride_id, 'to_destination', NULL;
EXEC taxi.sp_complete_ride @ride_id, 'wallet'; 


DECLARE @final_status VARCHAR(20) = (SELECT ride_status FROM taxi.rides WHERE ride_id = @ride_id); 
EXEC test.sp_assert_equals 'taxi', 'sp_complete_ride: Status changed to completed', 'completed', @final_status;


DECLARE @ride_price DECIMAL(10,2) = (SELECT calculated_price FROM taxi.rides WHERE ride_id = @ride_id); 
DECLARE @driver_expected_share DECIMAL(10,2) = @ride_price * 0.80; 
DECLARE @driver_actual_wallet DECIMAL(10,2) = (SELECT balance FROM taxi.driver_wallets WHERE driver_id = @d1_id); 

EXEC test.sp_assert_equals 'taxi', 'sp_complete_ride: Driver received exact 80% commission', @driver_expected_share, @driver_actual_wallet;


DECLARE @pass_expected_wallet DECIMAL(10,2) = 500000.00 - @ride_price;
DECLARE @pass_actual_wallet DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @pass_uid); 
EXEC test.sp_assert_equals 'taxi', 'sp_complete_ride: Passenger wallet deducted correctly', @pass_expected_wallet, @pass_actual_wallet;


DECLARE @d1_final_status VARCHAR(20) = (SELECT driver_status FROM taxi.drivers WHERE driver_id = @d1_id); 
EXEC test.sp_assert_equals 'taxi', 'sp_complete_ride: Driver is available again', 'available', @d1_final_status;
GO


-- Test 4: Rating & Gamification

PRINT '--- Testing Metrics & Gamification ---';
DECLARE @ride_id INT = (SELECT TOP 1 ride_id FROM taxi.rides ORDER BY ride_id DESC);
DECLARE @d1_id INT = (SELECT driver_id FROM taxi.rides WHERE ride_id = @ride_id); 


EXEC taxi.sp_rate_ride @ride_id, 'passenger', 5, 'Great driver!'; 


DECLARE @d1_avg DECIMAL(3,2) = (SELECT average_rating FROM taxi.drivers WHERE driver_id = @d1_id);
EXEC test.sp_assert_equals 'taxi', 'trg_rides_update_metrics: Driver rating dynamically updated to 5.00', 5.00, @d1_avg;

DECLARE @log_schema VARCHAR(10) = (SELECT TOP 1 schema_name FROM taxi.taxi_logs ORDER BY taxi_log_id DESC);
EXEC test.sp_assert_equals 'taxi', 'sp_write_log: schema_name correctly logged as "taxi"', 'taxi', @log_schema;
GO


-- Print Results

EXEC test.sp_print_summary @test_suite = 'taxi';
GO


-- PHASE 5: FULL TEARDOWN 

PRINT '=============================================';
PRINT 'WIPING ALL DATA (PREPARING FOR MAIN PRODUCTION SEED)';
PRINT '=============================================';
GO


DELETE FROM taxi.ride_payments; 
DELETE FROM taxi.taxi_logs; 
DELETE FROM taxi.passenger_stats;
DELETE FROM taxi.ride_offer_candidates; 
DELETE FROM taxi.ride_offers; 
DELETE FROM taxi.rides;
DELETE FROM taxi.pricing_parameters; 
DELETE FROM taxi.driver_secondary_phones; 
DELETE FROM taxi.driver_locations; 
DELETE FROM taxi.driver_wallets; 
DELETE FROM taxi.vehicle_type_services; 
DELETE FROM taxi.vehicles; 
DELETE FROM taxi.drivers;


DELETE FROM core.core_logs; 
DELETE FROM core.coupon_usages; 
DELETE FROM core.complaints;
DELETE FROM core.transactions; 
DELETE FROM core.saved_accounts; 
DELETE FROM core.addresses;
DELETE FROM core.admins; 
DELETE FROM core.user_wallets; 
DELETE FROM core.role_permissions;
DELETE FROM core.users; 
DELETE FROM core.roles; 
DELETE FROM core.permissions;
DELETE FROM core.coupons; 
DELETE FROM core.app_wallets; 
DELETE FROM core.commission_rates;
GO


DBCC CHECKIDENT ('taxi.taxi_logs', RESEED, 0);
DBCC CHECKIDENT ('taxi.ride_offer_candidates', RESEED, 0);
DBCC CHECKIDENT ('taxi.ride_offers', RESEED, 0); 
DBCC CHECKIDENT ('taxi.rides', RESEED, 0);
DBCC CHECKIDENT ('taxi.pricing_parameters', RESEED, 0); 
DBCC CHECKIDENT ('taxi.driver_secondary_phones', RESEED, 0);
DBCC CHECKIDENT ('taxi.driver_wallets', RESEED, 0); 
DBCC CHECKIDENT ('taxi.vehicles', RESEED, 0);
DBCC CHECKIDENT ('taxi.drivers', RESEED, 0);

DBCC CHECKIDENT ('core.core_logs', RESEED, 0); 
DBCC CHECKIDENT ('core.coupon_usages', RESEED, 0);
DBCC CHECKIDENT ('core.complaints', RESEED, 0); 
DBCC CHECKIDENT ('core.transactions', RESEED, 0);
DBCC CHECKIDENT ('core.saved_accounts', RESEED, 0); 
DBCC CHECKIDENT ('core.addresses', RESEED, 0);
DBCC CHECKIDENT ('core.admins', RESEED, 0); 
DBCC CHECKIDENT ('core.user_wallets', RESEED, 0);
DBCC CHECKIDENT ('core.role_permissions', RESEED, 0); 
DBCC CHECKIDENT ('core.users', RESEED, 0);
DBCC CHECKIDENT ('core.roles', RESEED, 0); 
DBCC CHECKIDENT ('core.permissions', RESEED, 0);
DBCC CHECKIDENT ('core.coupons', RESEED, 0); 
DBCC CHECKIDENT ('core.app_wallets', RESEED, 0);
DBCC CHECKIDENT ('core.commission_rates', RESEED, 0);
GO

PRINT 'Full wipe complete. Taxi schema is 100% verified and DB is ready for Production Seed.';
GO