USE mini_snapp;
GO

-- =============================================
-- SHARED SQL ASSERTION & RESET FRAMEWORK
-- =============================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'test')
BEGIN
    EXEC('CREATE SCHEMA test');
END
GO

IF OBJECT_ID('test.test_results', 'U') IS NULL
BEGIN
    CREATE TABLE test.test_results (
        test_result_id INT IDENTITY(1,1) NOT NULL,
        test_suite     VARCHAR(50)  NOT NULL,
        test_name      VARCHAR(200) NOT NULL,
        result         VARCHAR(10)  NOT NULL,
        expected_val   VARCHAR(500),
        actual_val     VARCHAR(500),
        run_at         DATETIME DEFAULT GETDATE(),
        CONSTRAINT pk_test_results PRIMARY KEY (test_result_id),
        CONSTRAINT chk_test_results_result CHECK (result IN ('PASS', 'FAIL'))
    );
END
GO

CREATE OR ALTER PROCEDURE test.sp_assert_equals
    @test_suite VARCHAR(50),
    @test_name  VARCHAR(200),
    @expected   SQL_VARIANT,
    @actual     SQL_VARIANT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @result VARCHAR(10);

    IF @expected = @actual OR (@expected IS NULL AND @actual IS NULL)
        SET @result = 'PASS';
    ELSE
        SET @result = 'FAIL';

    INSERT INTO test.test_results (test_suite, test_name, result, expected_val, actual_val)
    VALUES (@test_suite, @test_name, @result, CAST(@expected AS VARCHAR(500)), CAST(@actual AS VARCHAR(500)));

    IF @result = 'PASS'
        PRINT '  [PASS] ' + @test_name;
    ELSE
        PRINT '  [FAIL] ' + @test_name + ' | expected=' + ISNULL(CAST(@expected AS VARCHAR(500)), 'NULL') + ' actual=' + ISNULL(CAST(@actual AS VARCHAR(500)), 'NULL');
END
GO

CREATE OR ALTER PROCEDURE test.sp_assert_range
    @test_suite   VARCHAR(50),
    @test_name    VARCHAR(200),
    @actual       DECIMAL(18,4),
    @min_expected DECIMAL(18,4),
    @max_expected DECIMAL(18,4)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @result VARCHAR(10);
    DECLARE @expected_range VARCHAR(500) = 'between ' + CAST(@min_expected AS VARCHAR(50)) + ' and ' + CAST(@max_expected AS VARCHAR(50));

    IF @actual BETWEEN @min_expected AND @max_expected
        SET @result = 'PASS';
    ELSE
        SET @result = 'FAIL';

    INSERT INTO test.test_results (test_suite, test_name, result, expected_val, actual_val)
    VALUES (@test_suite, @test_name, @result, @expected_range, ISNULL(CAST(@actual AS VARCHAR(500)), 'NULL'));

    IF @result = 'PASS'
        PRINT '  [PASS] ' + @test_name;
    ELSE
        PRINT '  [FAIL] ' + @test_name + ' | expected=' + @expected_range + ' actual=' + ISNULL(CAST(@actual AS VARCHAR(500)), 'NULL');
END
GO

CREATE OR ALTER PROCEDURE test.sp_assert_true
    @test_suite VARCHAR(50),
    @test_name  VARCHAR(200),
    @condition  BIT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @result VARCHAR(10);

    IF @condition = 1
        SET @result = 'PASS';
    ELSE
        SET @result = 'FAIL';

    INSERT INTO test.test_results (test_suite, test_name, result, expected_val, actual_val)
    VALUES (@test_suite, @test_name, @result, '1 (true)', ISNULL(CAST(@condition AS VARCHAR(10)), 'NULL'));

    IF @result = 'PASS'
        PRINT '  [PASS] ' + @test_name;
    ELSE
        PRINT '  [FAIL] ' + @test_name + ' | expected condition to be true, was false';
END
GO

CREATE OR ALTER PROCEDURE test.sp_assert_not_null
    @test_suite VARCHAR(50),
    @test_name  VARCHAR(200),
    @value      SQL_VARIANT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @result VARCHAR(10);

    IF @value IS NOT NULL
        SET @result = 'PASS';
    ELSE
        SET @result = 'FAIL';

    INSERT INTO test.test_results (test_suite, test_name, result, expected_val, actual_val)
    VALUES (@test_suite, @test_name, @result, 'NOT NULL', ISNULL(CAST(@value AS VARCHAR(500)), 'NULL'));

    IF @result = 'PASS'
        PRINT '  [PASS] ' + @test_name;
    ELSE
        PRINT '  [FAIL] ' + @test_name + ' | expected a non-null value, got NULL';
END
GO

CREATE OR ALTER PROCEDURE test.sp_print_summary
    @test_suite VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @total INT, @passed INT, @failed INT;

    SELECT
        @total  = COUNT(*),
        @passed = ISNULL(SUM(CASE WHEN result = 'PASS' THEN 1 ELSE 0 END), 0),
        @failed = ISNULL(SUM(CASE WHEN result = 'FAIL' THEN 1 ELSE 0 END), 0)
    FROM test.test_results
    WHERE (@test_suite IS NULL OR test_suite = @test_suite);

    PRINT '=============================================';
    PRINT 'TEST SUMMARY - ' + ISNULL(@test_suite, 'ALL SUITES');
    PRINT 'Total:  ' + CAST(@total AS VARCHAR(10));
    PRINT 'Passed: ' + CAST(@passed AS VARCHAR(10));
    PRINT 'Failed: ' + CAST(@failed AS VARCHAR(10));
    PRINT '=============================================';

    IF @failed > 0
    BEGIN
        PRINT 'Failed tests:';
        SELECT test_suite, test_name, expected_val, actual_val
        FROM test.test_results
        WHERE result = 'FAIL'
          AND (@test_suite IS NULL OR test_suite = @test_suite);
    END
END
GO

CREATE OR ALTER PROCEDURE test.sp_reset_all_data
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Wipe cross-domain core links first
    DELETE FROM core.coupon_usages;
    DELETE FROM core.complaints;

    -- 2. Wipe food schema (children before parents)
    DELETE FROM food.order_payments;
    DELETE FROM food.order_items;
    DELETE FROM food.food_orders;
    DELETE FROM food.food_logs;
    DELETE FROM food.cart_items;
    DELETE FROM food.menu_discounts;
    DELETE FROM food.menu_items;
    DELETE FROM food.food_ingredients;
    DELETE FROM food.foods;
    DELETE FROM food.work_schedules;
    DELETE FROM food.business_phones;
    DELETE FROM food.restaurant_staff;
    DELETE FROM food.branch_owners;
    DELETE FROM food.branch_wallets;
    DELETE FROM food.branches;
    DELETE FROM food.brand_owners;
    DELETE FROM food.brands;
    DELETE FROM food.customer_stats;

    -- 3. Wipe taxi schema (children before parents)
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

    -- 4. Wipe core schema (children before parents)
    DELETE FROM core.core_logs;
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

    -- 5. Reseed identity columns
    DBCC CHECKIDENT ('food.order_payments', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('food.order_items', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('food.food_orders', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('food.food_logs', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('food.cart_items', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('food.menu_discounts', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('food.menu_items', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('food.food_ingredients', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('food.foods', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('food.work_schedules', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('food.business_phones', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('food.restaurant_staff', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('food.branch_owners', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('food.branch_wallets', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('food.branches', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('food.brand_owners', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('food.brands', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('food.customer_stats', RESEED, 0) WITH NO_INFOMSGS;

    DBCC CHECKIDENT ('taxi.taxi_logs', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('taxi.ride_offer_candidates', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('taxi.ride_offers', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('taxi.rides', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('taxi.pricing_parameters', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('taxi.driver_secondary_phones', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('taxi.driver_wallets', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('taxi.vehicles', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('taxi.drivers', RESEED, 0) WITH NO_INFOMSGS;

    DBCC CHECKIDENT ('core.core_logs', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.coupon_usages', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.complaints', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.transactions', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.saved_accounts', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.addresses', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.admins', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.user_wallets', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.role_permissions', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.users', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.roles', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.permissions', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.coupons', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.app_wallets', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.commission_rates', RESEED, 0) WITH NO_INFOMSGS;
END
GO
