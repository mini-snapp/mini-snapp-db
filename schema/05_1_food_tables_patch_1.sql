USE mini_snapp;
GO

CREATE TABLE food.food_orders (
    order_id INT IDENTITY(1,1) NOT NULL,
    customer_id INT NOT NULL,
    branch_id INT NOT NULL,
    delivery_address_id INT,
    delivery_fee DECIMAL(10,2) NOT NULL DEFAULT 0,
    final_price DECIMAL(10,2) NOT NULL,
    allocated_discount DECIMAL(10,2) NOT NULL DEFAULT 0,
    is_takeout BIT NOT NULL DEFAULT 0,
    ride_id INT,
    rating INT,
    comment NVARCHAR(1000),
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    confirmed_at DATETIME2,
    cooking_completed_at DATETIME2,
    estimated_cooking_time INT,
    handed_to_courier_at DATETIME2,
    delivered_at DATETIME2,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    rejection_reason VARCHAR(200),

    CONSTRAINT pk_food_orders
        PRIMARY KEY (order_id),
    CONSTRAINT fk_food_orders_customer
        FOREIGN KEY (customer_id) REFERENCES core.users(user_id),
    CONSTRAINT fk_food_orders_branch
        FOREIGN KEY (branch_id) REFERENCES food.branches(branch_id),
    CONSTRAINT fk_food_orders_address
        FOREIGN KEY (delivery_address_id) REFERENCES core.addresses(address_id),
    CONSTRAINT fk_food_orders_ride
        FOREIGN KEY (ride_id) REFERENCES taxi.rides(ride_id),
    CONSTRAINT ck_food_orders_status
        CHECK (status IN ('pending','confirmed','preparing','picked_up','delivered','cancelled','disputed')),
    CONSTRAINT ck_food_orders_rating
        CHECK (rating IS NULL OR rating BETWEEN 1 AND 5),
    CONSTRAINT ck_food_orders_delivery_address
        CHECK (is_takeout = 1 OR delivery_address_id IS NOT NULL)
);

GO

CREATE TABLE food.order_items (
    order_item_id INT IDENTITY(1,1) NOT NULL,
    order_id INT NOT NULL,
    menu_item_id INT NOT NULL,
    quantity INT NOT NULL,
    current_price DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_order_items
        PRIMARY KEY (order_item_id),
    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id) REFERENCES food.food_orders(order_id),
    CONSTRAINT fk_order_items_menu_item
        FOREIGN KEY (menu_item_id) REFERENCES food.menu_items(menu_item_id),
    CONSTRAINT ck_order_items_quantity
        CHECK (quantity > 0)
);

GO

CREATE TABLE food.order_payments (
    order_payment_id INT IDENTITY(1,1) NOT NULL,
    order_id INT NOT NULL,
    transaction_id INT NOT NULL,
    CONSTRAINT pk_order_payments
        PRIMARY KEY (order_payment_id),
    CONSTRAINT fk_order_payments_order
        FOREIGN KEY (order_id) REFERENCES food.food_orders(order_id),
    CONSTRAINT fk_order_payments_transaction
        FOREIGN KEY (transaction_id) REFERENCES core.transactions(transaction_id),
    CONSTRAINT uq_order_payments_order
        UNIQUE (order_id),
    CONSTRAINT uq_order_payments_transaction
        UNIQUE (transaction_id)
);

GO