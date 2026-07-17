USE mini_snapp;
GO

IF DATABASE_PRINCIPAL_ID('app_service') IS NULL
BEGIN
    CREATE ROLE app_service;
END
GO


GRANT EXECUTE ON SCHEMA::core TO app_service;
GRANT EXECUTE ON SCHEMA::food TO app_service;
GRANT EXECUTE ON SCHEMA::taxi TO app_service;


DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::core TO app_service;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::food TO app_service;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::taxi TO app_service;
GO


IF DATABASE_PRINCIPAL_ID('db_admin_role') IS NULL
BEGIN
    CREATE ROLE db_admin_role;
END
GO


GRANT CONTROL ON SCHEMA::core TO db_admin_role;
GRANT CONTROL ON SCHEMA::food TO db_admin_role;
GRANT CONTROL ON SCHEMA::taxi TO db_admin_role;
GO


IF DATABASE_PRINCIPAL_ID('readonly_analyst') IS NULL
BEGIN
    CREATE ROLE readonly_analyst;
END
GO


GRANT SELECT ON core.vw_active_coupons TO readonly_analyst;
GRANT SELECT ON core.vw_user_roles_permissions TO readonly_analyst;
GRANT SELECT ON core.vw_wallet_summary TO readonly_analyst;
GRANT SELECT ON core.vw_open_complaints TO readonly_analyst;
GO


