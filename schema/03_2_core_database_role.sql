USE mini_snapp
GO

CREATE ROLE app_service;

GO

GRANT EXECUTE ON SCHEMA::core TO app_service;
GRANT EXECUTE ON SCHEMA::food TO app_service;
GRANT EXECUTE ON SCHEMA::taxi TO app_service;

DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::core TO app_service;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::food TO app_service;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::taxi TO app_service;
GO

CREATE ROLE db_admin_role;

GO

GRANT CONTROL ON SCHEMA::core TO db_admin_role;
GRANT CONTROL ON SCHEMA::food TO db_admin_role;
GRANT CONTROL ON SCHEMA::taxi TO db_admin_role;

GO

CREATE ROLE readonly_analyst;

Go

GRANT SELECT ON core.vw_active_coupons TO readonly_analyst;
GRANT SELECT ON core.vw_user_roles_permissions TO readonly_analyst;
GRANT SELECT ON core.vw_wallet_summary TO readonly_analyst;
GRANT SELECT ON core.vw_open_complaints TO readonly_analyst;

Go 

--TODO:  when food/taxi views and ... created , somthing must add here