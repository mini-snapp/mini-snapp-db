USE mini_snapp;
GO

CREATE TABLE food.brands (
    brand_id INT IDENTITY(1,1) NOT NULL,
    name VARCHAR(100) NOT NULL,
    central_support_phone VARCHAR(20),
    commission_rate DECIMAL(5,4),
    average_rating DECIMAL(3,2) NOT NULL DEFAULT 0,
    rating_count INT NOT NULL DEFAULT 0,
    email VARCHAR(100),

    CONSTRAINT pk_brands 
        PRIMARY KEY (brand_id),

    CONSTRAINT uq_brands_name 
        UNIQUE (name),

    CONSTRAINT ck_brands_average_rating 
        CHECK (average_rating BETWEEN 0 AND 5)
);

GO

CREATE TABLE food.brand_owners (
    brand_owner_id INT IDENTITY(1,1) NOT NULL,
    user_id INT NOT NULL,
    brand_id INT NOT NULL,

    CONSTRAINT pk_brand_owners 
        PRIMARY KEY (brand_owner_id),

    CONSTRAINT fk_brand_owners_user 
        FOREIGN KEY (user_id) REFERENCES core.users(user_id),

    CONSTRAINT fk_brand_owners_brand 
        FOREIGN KEY (brand_id) REFERENCES food.brands(brand_id),

    CONSTRAINT uq_brand_owners_user_brand 
        UNIQUE (user_id, brand_id)
);

GO

CREATE TABLE food.branches (
    branch_id INT IDENTITY(1,1) NOT NULL,
    brand_id INT NOT NULL,
    rating DECIMAL(3,2) NOT NULL DEFAULT 0,
    province VARCHAR(50) NOT NULL,
    city VARCHAR(50) NOT NULL,
    street VARCHAR(150) NOT NULL,
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,
    email VARCHAR(100),
    food_type VARCHAR(50) NOT NULL,
    max_delivery_distance DECIMAL(6,2) NOT NULL,
    is_active BIT NOT NULL DEFAULT 1,
    rating_count INT NOT NULL DEFAULT 0,

    CONSTRAINT pk_branches 
        PRIMARY KEY (branch_id),

    CONSTRAINT fk_branches_brand 
        FOREIGN KEY (brand_id) REFERENCES food.brands(brand_id),

    CONSTRAINT ck_branches_rating 
        CHECK (rating BETWEEN 0 AND 5)
);

GO

CREATE TABLE food.branch_wallets (
    branch_wallet_id INT IDENTITY(1,1) NOT NULL,
    branch_id INT NOT NULL,
    balance DECIMAL(12,2) NOT NULL DEFAULT 0,

    CONSTRAINT pk_branch_wallets 
        PRIMARY KEY (branch_wallet_id),

    CONSTRAINT uq_branch_wallets_branch_id 
        UNIQUE (branch_id),

    CONSTRAINT fk_branch_wallets_branch 
        FOREIGN KEY (branch_id) REFERENCES food.branches(branch_id)
);

GO

CREATE TABLE food.branch_owners (
    branch_owner_id INT IDENTITY(1,1) NOT NULL,
    user_id INT NOT NULL,
    branch_id INT NOT NULL,

    CONSTRAINT pk_branch_owners 
        PRIMARY KEY (branch_owner_id),

    CONSTRAINT fk_branch_owners_user 
        FOREIGN KEY (user_id) REFERENCES core.users(user_id),

    CONSTRAINT fk_branch_owners_branch 
        FOREIGN KEY (branch_id) REFERENCES food.branches(branch_id),

    CONSTRAINT uq_branch_owners_user_branch 
        UNIQUE (user_id, branch_id)
);

GO

CREATE TABLE food.restaurant_staff (
    restaurant_staff_id INT IDENTITY(1,1) NOT NULL,
    user_id INT NOT NULL,
    branch_id INT NOT NULL,

    CONSTRAINT pk_restaurant_staff 
        PRIMARY KEY (restaurant_staff_id),

    CONSTRAINT fk_restaurant_staff_user 
        FOREIGN KEY (user_id) REFERENCES core.users(user_id),

    CONSTRAINT fk_restaurant_staff_branch 
        FOREIGN KEY (branch_id) REFERENCES food.branches(branch_id),

    CONSTRAINT uq_restaurant_staff_user_branch 
        UNIQUE (user_id, branch_id)
);

GO

CREATE TABLE food.business_phones (
    business_phone_id INT IDENTITY(1,1) NOT NULL,
    branch_id INT NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    phone_type VARCHAR(20) NOT NULL,

    CONSTRAINT pk_business_phones 
        PRIMARY KEY (business_phone_id),

    CONSTRAINT fk_business_phones_branch 
        FOREIGN KEY (branch_id) REFERENCES food.branches(branch_id)
);

GO

CREATE TABLE food.work_schedules (
    work_schedule_id INT IDENTITY(1,1) NOT NULL,
    branch_id INT NOT NULL,
    day_of_week INT NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_closed BIT NOT NULL,

    CONSTRAINT pk_work_schedules 
        PRIMARY KEY (work_schedule_id),

    CONSTRAINT fk_work_schedules_branch 
        FOREIGN KEY (branch_id) REFERENCES food.branches(branch_id),

    CONSTRAINT uq_work_schedules_branch_day 
        UNIQUE (branch_id, day_of_week),

    CONSTRAINT ck_work_schedules_day_of_week 
        CHECK (day_of_week BETWEEN 0 AND 6)
);

GO

CREATE TABLE food.foods (
    food_id INT IDENTITY(1,1) NOT NULL,
    brand_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    average_rating DECIMAL(3,2) NOT NULL DEFAULT 0,
    rating_count INT NOT NULL DEFAULT 0,

    CONSTRAINT pk_foods 
        PRIMARY KEY (food_id),

    CONSTRAINT fk_foods_brand 
        FOREIGN KEY (brand_id) REFERENCES food.brands(brand_id),

    CONSTRAINT ck_foods_average_rating 
        CHECK (average_rating BETWEEN 0 AND 5)
);

GO

CREATE TABLE food.food_ingredients (
    food_ingredient_id INT IDENTITY(1,1) NOT NULL,
    food_id INT NOT NULL,
    ingredient_name VARCHAR(100) NOT NULL,
    amount DECIMAL(8,2) NOT NULL,
    unit VARCHAR(20) NOT NULL,

    CONSTRAINT pk_food_ingredients 
        PRIMARY KEY (food_ingredient_id),

    CONSTRAINT fk_food_ingredients_food 
        FOREIGN KEY (food_id) REFERENCES food.foods(food_id)
);

GO

CREATE TABLE food.menu_items (
    menu_item_id INT IDENTITY(1,1) NOT NULL,
    branch_id INT NOT NULL,
    food_id INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    availability_status BIT NOT NULL DEFAULT 1,
    average_rating DECIMAL(3,2) NOT NULL DEFAULT 0,
    rating_count INT NOT NULL DEFAULT 0,
    estimated_prep_time INT NOT NULL,
    available_from TIME,
    available_to TIME,

    CONSTRAINT pk_menu_items 
        PRIMARY KEY (menu_item_id),

    CONSTRAINT fk_menu_items_branch 
        FOREIGN KEY (branch_id) REFERENCES food.branches(branch_id),

    CONSTRAINT fk_menu_items_food 
        FOREIGN KEY (food_id) REFERENCES food.foods(food_id),

    CONSTRAINT uq_menu_items_branch_food 
        UNIQUE (branch_id, food_id),

    CONSTRAINT ck_menu_items_average_rating 
        CHECK (average_rating BETWEEN 0 AND 5)
);

GO

CREATE TABLE food.menu_discounts (
    menu_discount_id INT IDENTITY(1,1) NOT NULL,
    menu_item_id INT NOT NULL,
    percentage DECIMAL(5,2),
    amount DECIMAL(10,2),
    start_at DATETIME NOT NULL,
    end_at DATETIME NOT NULL,
    is_active BIT NOT NULL DEFAULT 1,

    CONSTRAINT pk_menu_discounts 
        PRIMARY KEY (menu_discount_id),

    CONSTRAINT fk_menu_discounts_menu_item 
        FOREIGN KEY (menu_item_id) REFERENCES food.menu_items(menu_item_id),

    CONSTRAINT ck_menu_discounts_date_range 
        CHECK (end_at > start_at)

);

GO

CREATE TABLE food.cart_items (
    cart_item_id INT IDENTITY(1,1) NOT NULL,
    user_id INT NOT NULL,
    branch_id INT NOT NULL,
    menu_item_id INT NOT NULL,
    quantity INT NOT NULL,

    CONSTRAINT pk_cart_items 
        PRIMARY KEY (cart_item_id),

    CONSTRAINT fk_cart_items_user 
        FOREIGN KEY (user_id) REFERENCES core.users(user_id),

    CONSTRAINT fk_cart_items_branch 
        FOREIGN KEY (branch_id) REFERENCES food.branches(branch_id),

    CONSTRAINT fk_cart_items_menu_item 
        FOREIGN KEY (menu_item_id) REFERENCES food.menu_items(menu_item_id),

    CONSTRAINT uq_cart_items_user_branch_menu_item 
        UNIQUE (user_id, branch_id, menu_item_id),

    CONSTRAINT ck_cart_items_quantity 
        CHECK (quantity > 0)
);

GO

CREATE TABLE food.customer_stats (
    customer_stat_id INT IDENTITY(1,1) NOT NULL,
    user_id INT NOT NULL,
    score INT NOT NULL DEFAULT 0,
    rank VARCHAR(20),

    CONSTRAINT pk_customer_stats 
        PRIMARY KEY (customer_stat_id),

    CONSTRAINT fk_customer_stats_user 
        FOREIGN KEY (user_id) REFERENCES core.users(user_id),

    CONSTRAINT uq_customer_stats_user_id 
        UNIQUE (user_id)

);

GO

CREATE TABLE food.food_logs (
    food_log_id INT IDENTITY(1,1) NOT NULL,
    actor_id INT NOT NULL,
    operation_type VARCHAR(50) NOT NULL,
    schema_name VARCHAR(50) NOT NULL,
    target_table VARCHAR(50) NOT NULL,
    target_id VARCHAR(50) NOT NULL,
    old_value NVARCHAR(MAX),
    new_value NVARCHAR(MAX),
    log_timestamp DATETIME NOT NULL DEFAULT SYSDATETIME(),
    description VARCHAR(500),
    branch_id INT NOT NULL,

    CONSTRAINT pk_food_logs 
        PRIMARY KEY (food_log_id),

    CONSTRAINT fk_food_logs_actor 
        FOREIGN KEY (actor_id) REFERENCES core.users(user_id),

    CONSTRAINT fk_food_logs_branch 
        FOREIGN KEY (branch_id) REFERENCES food.branches(branch_id)
);

GO