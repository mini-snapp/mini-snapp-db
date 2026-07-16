USE mini_snapp;
GO

IF OBJECT_ID('food.sp_write_log', 'P') IS NOT NULL
    DROP PROCEDURE food.sp_write_log;
GO
CREATE PROCEDURE food.sp_write_log
    @actor_id INT = NULL, @operation_type VARCHAR(10), @target_table VARCHAR(50), @target_id VARCHAR(50),
    @old_value NVARCHAR(MAX) = NULL, @new_value NVARCHAR(MAX) = NULL,
    @description VARCHAR(500) = NULL, @branch_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @resolved_actor_id INT = @actor_id;
    IF @resolved_actor_id IS NULL
        SET @resolved_actor_id = (SELECT user_id FROM core.users WHERE username = 'admin_yasaman');
    INSERT INTO food.food_logs (actor_id, operation_type, schema_name, target_table, target_id, old_value, new_value, log_timestamp, description, branch_id)
    VALUES (@resolved_actor_id, @operation_type, 'food', @target_table, @target_id, @old_value, @new_value, SYSDATETIME(), @description, @branch_id);
END

GO