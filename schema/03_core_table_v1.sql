USE mini_snapp;
GO


-- 1. Core Tables


CREATE TABLE core.roles (
    role_id INT IDENTITY(1,1) NOT NULL,
    role_name VARCHAR(20) NOT NULL,
    role_description VARCHAR(150),
    hierarchy_level INT NOT NULL DEFAULT 0,

    CONSTRAINT pk_roles 
        PRIMARY KEY (role_id),

    CONSTRAINT uq_roles_role_name 
        UNIQUE (role_name)
);
GO

CREATE TABLE core.permissions(
    permission_id INT IDENTITY(1,1) NOT NULL,
    permission_name VARCHAR(50) NOT NULL,
    permission_description VARCHAR(150),

    CONSTRAINT pk_permissions 
        PRIMARY KEY (permission_id),

    CONSTRAINT uq_permissions_permission_name 
        UNIQUE (permission_name)
);
GO

CREATE TABLE core.coupons (
    coupon_id INT IDENTITY(1,1) NOT NULL,
    code VARCHAR(20) NOT NULL,
    [percentage] DECIMAL(5,2),
    amount DECIMAL(10,2),
    min_requirement DECIMAL(10,2),
    max_cap DECIMAL(10,2),
    [expiry_date] DATETIME , -- اگه نال باشه یعنی بدون محدودیت زمان مثلا برای اولین خرید همه
    current_usage INT DEFAULT 0,
    max_usage INT NOT NULL,
    is_active BIT DEFAULT 1,

    CONSTRAINT pk_coupons
        PRIMARY KEY (coupon_id),
    
    CONSTRAINT uq_coupons_code 
        UNIQUE (code),

    CONSTRAINT chk_coupons_value 
        CHECK( [percentage] IS NOT NULL OR amount IS NOT NULL)
);
GO

CREATE TABLE core.app_wallets(
    app_wallet_id INT IDENTITY(1,1) NOT NULL ,
    total_balance DECIMAL(10,2) NOT NULL DEFAULT 0,

    CONSTRAINT pk_app_wallet PRIMARY KEY (app_wallet_id)
);
GO

CREATE TABLE core.commission_rates (
    commission_rate_id INT IDENTITY(1,1) NOT NULL ,
    service_type VARCHAR(20) NOT NULL,
    driver_share DECIMAL(5,2) NOT NULL,
    restaurant_share DECIMAL(5,2) ,
    app_share DECIMAL(5,2) NOT NULL,
    effective_from DATETIME NOT NULL,
    effective_to DATETIME ,
    
    CONSTRAINT pk_commission_rates 
        PRIMARY KEY (commission_rate_id),

    CONSTRAINT chk_commission_rates_service_type 
        CHECK (service_type IN ('food', 'taxi'))
);
GO

CREATE TABLE core.users(
    user_id INT IDENTITY(1,1) NOT NULL,
    username VARCHAR(50) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    registration_phone VARCHAR(15) NOT NULL,
    email VARCHAR(100),
    role_id INT NOT NULL,
    created_at DATETIME DEFAULT GETDATE(),
    is_blocked BIT DEFAULT 0,
    deleted_at DATETIME,

    CONSTRAINT pk_users 
        PRIMARY KEY (user_id),

    CONSTRAINT uq_users_username 
        UNIQUE (username),
        
    CONSTRAINT uq_users_registration_phone 
        UNIQUE (registration_phone),

    CONSTRAINT fk_users_role_id 
        FOREIGN KEY (role_id) REFERENCES core.roles(role_id)
);
GO

CREATE UNIQUE INDEX uq_users_email 
    ON core.users(email) 
    WHERE email IS NOT NULL;
GO

CREATE TABLE core.role_permissions (
    role_permissions_id INT IDENTITY(1,1) NOT NULL,
    role_id INT NOT NULL,
    permission_id INT NOT NULL,

    CONSTRAINT pk_role_permissions 
        PRIMARY KEY (role_permissions_id),
    
    CONSTRAINT uq_role_permissions_role_and_permission 
        UNIQUE (role_id,permission_id),

    CONSTRAINT fk_role_permissions_role_id 
        FOREIGN KEY (role_id) REFERENCES core.roles(role_id),
    
    CONSTRAINT fk_role_permissions_permission_id
        FOREIGN KEY (permission_id) REFERENCES core.permissions(permission_id)
);
GO 

CREATE TABLE core.user_wallets (
    user_wallet_id INT IDENTITY(1,1) NOT NULL ,
    user_id INT NOT NULL ,
    balance DECIMAL(10,2) NOT NULL DEFAULT 0,

    CONSTRAINT pk_user_wallets 
        PRIMARY KEY (user_wallet_id),

    CONSTRAINT uq_user_wallets_user_id 
        UNIQUE (user_id),

    CONSTRAINT fk_user_wallets_user_id 
        FOREIGN KEY (user_id) REFERENCES core.users(user_id)
);
GO

CREATE TABLE core.admins (
    admin_id INT IDENTITY(1,1) NOT NULL ,
    user_id INT NOT NULL ,
    admin_identifier VARCHAR(20) NOT NULL,
    access_level VARCHAR(20) NOT NULL ,

    CONSTRAINT pk_admins 
        PRIMARY KEY (admin_id),

    CONSTRAINT uq_admins_user_id 
        UNIQUE (user_id),
    
    CONSTRAINT uq_admins_identifier 
        UNIQUE (admin_identifier),
    
    CONSTRAINT fk_admins_user_id 
        FOREIGN KEY (user_id) REFERENCES core.users(user_id)
);
GO 

CREATE TABLE core.saved_accounts (
    saved_account_id INT IDENTITY(1,1) NOT NULL,
    user_id INT NOT NULL ,
    card_number VARCHAR(20) NOT NULL ,
    bank_name VARCHAR(50) NOT NULL,

    CONSTRAINT pk_saved_accounts 
        PRIMARY KEY (saved_account_id),

    CONSTRAINT fk_saved_acounts_user_id 
        FOREIGN KEY (user_id) REFERENCES core.users(user_id)
);
GO

CREATE TABLE core.transactions (
    transaction_id INT IDENTITY(1,1) NOT NULL,
    user_id INT NOT NULL,
    transaction_type VARCHAR(20) NOT NULL,
    transaction_status VARCHAR(15) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(15) NOT NULL,
    coupon_id INT ,
    created_at DATETIME DEFAULT GETDATE(),

    CONSTRAINT pk_transactions 
        PRIMARY KEY (transaction_id),
    
    CONSTRAINT fk_transactions_user_id 
        FOREIGN KEY (user_id) REFERENCES core.users(user_id),
    
    CONSTRAINT fk_transactions_coupon_id 
        FOREIGN KEY (coupon_id) REFERENCES core.coupons(coupon_id),
    
    CONSTRAINT chk_transactions_type 
        CHECK (transaction_type IN (
            'wallet_charge','order_payment','ride_payment','refund','withdrawal','payout')),
    
    CONSTRAINT chk_transactions_status 
        CHECK (transaction_status IN (
            'pending','completed','failed','reversed')),
    
    CONSTRAINT chk_transactions_payment_method 
        CHECK (payment_method IN ('wallet','card','cash'))
);
GO

CREATE TABLE core.addresses (
    address_id INT IDENTITY(1,1) NOT NULL,
    user_id INT NOT NULL,
    address_name VARCHAR(50)  NOT NULL,
    province VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    street VARCHAR(100) NOT NULL,
    description_text TEXT,
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,

    CONSTRAINT pk_addresses 
        PRIMARY KEY (address_id),

    CONSTRAINT fk_addresses_user_id 
        FOREIGN KEY (user_id) REFERENCES core.users(user_id)
);
GO 

CREATE TABLE core.complaints (
    complaint_id INT IDENTITY(1,1) NOT NULL,
    reporter_id INT NOT NULL,
    target_type VARCHAR(20)  NOT NULL,
    target_id INT NOT NULL,
    title VARCHAR(150) NOT NULL,
    complaint_description TEXT NOT NULL,
    complaint_status VARCHAR(15)  NOT NULL DEFAULT 'open',
    assigned_admin_id INT ,
    created_at DATETIME DEFAULT GETDATE(),
    resolved_at DATETIME ,

    CONSTRAINT pk_complaints 
        PRIMARY KEY (complaint_id),

    CONSTRAINT fk_complaints_reporter_id 
        FOREIGN KEY (reporter_id) REFERENCES core.users(user_id),

    CONSTRAINT fk_complaints_assigned_admin_id 
        FOREIGN KEY (assigned_admin_id) REFERENCES core.admins(admin_id),
    
    CONSTRAINT chk_complaints_target_type 
        CHECK (target_type IN ('branch','driver','brand','user')),
    
    CONSTRAINT chk_complaints_status 
        CHECK (complaint_status IN ('open','in_review','resolved','rejected'))
);
GO

CREATE TABLE core.core_logs (
    core_log_id INT IDENTITY(1,1) NOT NULL,
    actor_id INT NULL,
    operation_type VARCHAR(10) NOT NULL,
    schema_name VARCHAR(10) NOT NULL,
    target_table VARCHAR(50) NOT NULL,
    target_id VARCHAR(50) NOT NULL,
    old_value NVARCHAR(MAX) ,
    new_value NVARCHAR(MAX) ,
    created_at DATETIME DEFAULT GETDATE(),
    [description] TEXT ,

    CONSTRAINT pk_core_logs 
        PRIMARY KEY (core_log_id),

    CONSTRAINT fk_core_logs_actor_id 
        FOREIGN KEY (actor_id) REFERENCES core.users(user_id),

    CONSTRAINT chk_core_logs_operation_type 
        CHECK (operation_type IN ('insert','update','delete')),

    CONSTRAINT chk_core_logs_schema_name 
        CHECK (schema_name IN ('core','food','taxi'))
);
GO

CREATE TABLE core.coupon_usages (
    coupon_usage_id INT IDENTITY(1,1) NOT NULL,
    coupon_id INT NOT NULL,
    user_id INT NOT NULL,
    used_at DATETIME DEFAULT GETDATE(),
    order_id INT ,
    ride_id INT ,

    CONSTRAINT pk_coupon_usages 
        PRIMARY KEY (coupon_usage_id),

    CONSTRAINT fk_coupon_usages_coupon_id 
        FOREIGN KEY (coupon_id) REFERENCES core.coupons(coupon_id),

    CONSTRAINT fk_coupon_usages_user_id 
        FOREIGN KEY (user_id) REFERENCES core.users(user_id),
    
    CONSTRAINT chk_coupon_usages_order_or_ride
        CHECK (order_id IS NOT NULL OR ride_id IS NOT NULL)
);
GO


-- 2. Database Roles & Security


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
