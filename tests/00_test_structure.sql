USE mini_snapp
GO

CREATE TABLE test.test_results (
        test_result_id           INT IDENTITY(1,1) NOT NULL,
        test_suite   VARCHAR(50)  NOT NULL,   --'core', 'food', 'taxi'
        test_name    VARCHAR(200) NOT NULL,
        result       VARCHAR(10)  NOT NULL,   -- 'PASS' or 'FAIL'
        expected_val VARCHAR(500) ,
        actual_val   VARCHAR(500) ,
        run_at       DATETIME DEFAULT GETDATE(),
 
        CONSTRAINT pk_test_results PRIMARY KEY (test_result_id),
        CONSTRAINT chk_test_results_result CHECK (result IN ('PASS','FAIL'))
);

GO

CREATE PROCEDURE test.sp_assert_equals
    @test_suite  VARCHAR(50),
    @test_name   VARCHAR(200),
    @expected    SQL_VARIANT,
    @actual      SQL_VARIANT
AS
BEGIN
    SET NOCOUNT ON;
 
    DECLARE @result VARCHAR(10);
 
    IF @expected = @actual OR (@expected IS NULL AND @actual IS NULL)
        SET @result = 'PASS';
    ELSE
        SET @result = 'FAIL';
 
    INSERT INTO test.test_results 
        (test_suite, test_name, result, expected_val, actual_val)
    VALUES 
        (@test_suite, @test_name, @result, CAST(@expected AS VARCHAR(500)), CAST(@actual AS VARCHAR(500)));
 
    IF @result = 'PASS'
        PRINT '  [PASS] ' + @test_name;
    ELSE
        PRINT '  [FAIL] ' + @test_name + ' | expected=' + 
            CAST(@expected AS VARCHAR(500)) + ' actual=' + CAST(@actual AS VARCHAR(500));
END


GO

CREATE PROCEDURE test.sp_assert_range
    @test_suite    VARCHAR(50),
    @test_name     VARCHAR(200),
    @actual        DECIMAL(18,4),
    @min_expected  DECIMAL(18,4),
    @max_expected  DECIMAL(18,4)
AS
BEGIN
    SET NOCOUNT ON;
 
    DECLARE @result VARCHAR(10);
    DECLARE @expected_range VARCHAR(500) = 'between ' 
        + CAST(@min_expected AS VARCHAR(50)) + ' and ' + CAST(@max_expected AS VARCHAR(50));
 
    IF @actual BETWEEN @min_expected AND @max_expected
        SET @result = 'PASS';
    ELSE
        SET @result = 'FAIL';
 
    INSERT INTO test.test_results 
        (test_suite, test_name, result, expected_val, actual_val)
    VALUES
        (@test_suite, @test_name, @result, @expected_range, CAST(@actual AS VARCHAR(500)));
 
    IF @result = 'PASS'
        PRINT '  [PASS] ' + @test_name;
    ELSE
        PRINT '  [FAIL] ' + @test_name + ' | expected=' + @expected_range + ' actual=' + CAST(@actual AS VARCHAR(500));
END

GO

CREATE PROCEDURE test.sp_assert_true
    @test_suite  VARCHAR(50),
    @test_name   VARCHAR(200),
    @condition   BIT
AS
BEGIN
    SET NOCOUNT ON;
 
    DECLARE @result VARCHAR(10);
 
    IF @condition = 1
        SET @result = 'PASS';
    ELSE
        SET @result = 'FAIL';
 
    INSERT INTO test.test_results 
        (test_suite, test_name, result, expected_val, actual_val)
    VALUES 
        (@test_suite, @test_name, @result, '1 (true)', CAST(@condition AS VARCHAR(10)));
 
    IF @result = 'PASS'
        PRINT '  [PASS] ' + @test_name;
    ELSE
        PRINT '  [FAIL] ' + @test_name 
            + ' | expected condition to be true, was false';
END

GO

CREATE PROCEDURE test.sp_assert_not_null
    @test_suite  VARCHAR(50),
    @test_name   VARCHAR(200),
    @value       SQL_VARIANT
AS
BEGIN
    SET NOCOUNT ON;
 
    DECLARE @result VARCHAR(10);
 
    IF @value IS NOT NULL
        SET @result = 'PASS';
    ELSE
        SET @result = 'FAIL';
 
    INSERT INTO test.test_results 
        (test_suite, test_name, result, expected_val, actual_val)
    VALUES 
        (@test_suite, @test_name, @result, 'NOT NULL', CAST(@value AS VARCHAR(500)));
 
    IF @result = 'PASS'
        PRINT '  [PASS] ' + @test_name;
    ELSE
        PRINT '  [FAIL] ' + @test_name 
            + ' | expected a non-null value, got NULL';
END

GO

CREATE PROCEDURE test.sp_print_summary
    @test_suite VARCHAR(50) = NULL   -- NULL means "all suites, most recent run"
AS
BEGIN
    SET NOCOUNT ON;
 
    DECLARE @total INT, @passed INT, @failed INT;
 
    SELECT
        @total  = COUNT(*),
        @passed = SUM(CASE WHEN result = 'PASS' THEN 1 ELSE 0 END),
        @failed = SUM(CASE WHEN result = 'FAIL' THEN 1 ELSE 0 END)
    FROM test.test_results
    WHERE (@test_suite IS NULL OR test_suite = @test_suite);
 
    PRINT '=============================================';
    PRINT 'TEST SUMMARY' + ISNULL(' — ' + @test_suite, ' — ALL SUITES');
    PRINT 'Total:  ' + CAST(@total AS VARCHAR(10));
    PRINT 'Passed: ' + CAST(@passed AS VARCHAR(10));
    PRINT 'Failed: ' + CAST(@failed AS VARCHAR(10));
    PRINT '=============================================';
 
    IF @failed > 0
    BEGIN
        PRINT 'Failed tests:';
        SELECT test_name, expected_val, actual_val
        FROM test.test_results
        WHERE result = 'FAIL' AND (@test_suite IS NULL OR test_suite = @test_suite);
    END
END