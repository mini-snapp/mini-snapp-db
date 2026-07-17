USE mini_snapp;
GO

IF EXISTS(SELECT 1 FROM sys.columns WHERE name = N'permissions_name' AND object_id = OBJECT_ID(N'core.permissions'))
BEGIN
    EXEC sp_rename 'core.permissions.permissions_name', 'permission_name', 'COLUMN';
END
GO

IF EXISTS(SELECT 1 FROM sys.columns WHERE name = N'permissions_description' AND object_id = OBJECT_ID(N'core.permissions'))
BEGIN
    EXEC sp_rename 'core.permissions.permissions_description', 'permission_description', 'COLUMN';
END
GO


IF OBJECT_ID('core.uq_premissions_permission_name', 'UQ') IS NOT NULL
BEGIN
    ALTER TABLE core.permissions DROP CONSTRAINT uq_premissions_permission_name;
END
GO

IF OBJECT_ID('core.uq_permissions_permission_name', 'UQ') IS NULL
BEGIN
    ALTER TABLE core.permissions ADD CONSTRAINT uq_permissions_permission_name UNIQUE (permission_name);
END
GO

IF EXISTS(SELECT 1 FROM sys.columns WHERE name = N'create_at' AND object_id = OBJECT_ID(N'core.core_logs'))
BEGIN
    EXEC sp_rename 'core.core_logs.create_at', 'created_at', 'COLUMN';
END
GO

IF OBJECT_ID('core.uq_users_registration_phone', 'UQ') IS NULL
BEGIN
    ALTER TABLE core.users ADD CONSTRAINT uq_users_registration_phone UNIQUE (registration_phone);
END
GO

IF OBJECT_ID('core.uq_users_email', 'UQ') IS NULL
BEGIN
    ALTER TABLE core.users ADD CONSTRAINT uq_users_email UNIQUE (email);
END
GO


IF OBJECT_ID('core.user_favorite_foods', 'U') IS NOT NULL
BEGIN
    DROP TABLE core.user_favorite_foods;
END
GO