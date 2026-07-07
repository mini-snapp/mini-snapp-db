USE mini_snapp

GO

CREATE TABLE taxi.vehicles(
    vehicle_id INT IDENTITY(1,1) NOT NULL,
    owner_id INT NOT NULL,
    vehicle_type VARCHAR(20) NOT NULL,
    license_plate VARCHAR(20) NOT NULL,
    color VARCHAR(20) NOT NULL ,
    model_name VARCHAR(20) NOT NULL ,

    CONSTRAINT pk_vehicles_vehicle_id 
        PRIMARY KEY (vehicle_id),
    
    CONSTRAINT fk_vehicles_user_id 
        FOREIGN KEY (owner_id) REFERENCES core.users(id), -- !!!
    
)

Go

CREATE TABLE taxi.drivers(
    driver_id INT IDENTITY(1,1) NOT NULL,
    user_id INT NOT NULL,
    national_id VARCHAR(15) NOT NULL,
    Date_of_birth DATE NOT NULL , -- user for cal age
    driver_status VARCHAR(20),
    gender VARCHAR(15),
    average_rating DECIMAL(3,2) DEFAULT 0.00,
    rating_count INT DEFAULT 0,
    activity_points INT DEFAULT 0, -- rank ba tarkib avg rating va activity_point hesab mishe
    active_vehicle_id INT ,

    CONSTRAINT pk_drivers_driver_id 
        PRIMARY KEY (driver_id),

    CONSTRAINT fk_drivers_user_id 
        FOREIGN KEY (user_id) REFERENCES core.users(user_id),

    CONSTRAINT fk_drivers_active_vehicle_id
        FOREIGN KEY (active_vehicle_id) REFERENCES taxi.vehicles(vehicle_id),

    
);

Go

CREATE TABLE taxi.driver_wallets(
    driver_wallet_id INT IDENTITY(1,1) NOT NULL ,
    driver_id INT NOT NULL,
    balance DECIMAL(10,2) DEFAULT 0 ,

    CONSTRAINT pk_driver_wallets_driver_wallet_id 
        PRIMARY KEY (driver_wallet_id),

    CONSTRAINT fk_driver_wallets_driver_id 
        FOREIGN KEY (driver_id) REFERENCES taxi.drivers(driver_id)
);

Go

CREATE TABLE taxi.driver_locations(
    driver_locarion_id INT IDENTITY(1,1) NOT NULL ,
    driver_id INT NOT NULL ,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    update_at DATETIME

    CONSTRAINT pk_driver_locations_driver_location_id
        PRIMARY KEY (driver_locarion_id),

    CONSTRAINT uq_driver_locations_driver_id
        UNIQUE (driver_id),
    
    CONSTRAINT fk_driver_locations_driver_id
        FOREIGN KEY (driver_id) REFERENCES taxi.drivers(driver_id),
)

GO

CREATE TABLE taxi.driver_secondary_phones(
    driver_secondary_phone_id INT IDENTITY(1,1) NOT NULL,
    driver_id INT NOT NULL,
    phone_label VARCHAR(50),
    phone_number VARCHAR(15),

    CONSTRAINT pk_driver_secondary_phones_driver_secondary_phone_id
        PRIMARY KEY (driver_secondary_phone_id),
    
    CONSTRAINT fk_driver_secondary_phones_id_driver_id
        FOREIGN KEY (driver_id) REFERENCES taxi.drivers(driver_id),
    
    CONSTRAINT uq_driver_secondary_phones_id_driver_id_phone_number
        UNIQUE (driver_id , phone_number),
    
    CONSTRAINT uq_driver_secondary_phones_id_driver_id_phone_number
        UNIQUE (phone_number)
);

GO

CREATE TABLE taxi.rides(
    ride_id INT IDENTITY(1,1) NOT NULL ,
    passenger_id INT NOT NULL ,
    driver_id INT NOT NULL ,
    vehicle_id INT NOT NULL,
    origin_province VARCHAR(100),
    origin_city VARCHAR(100),
    origin_street VARCHAR(100),
    origin_latitude DECIMAL(10,8)NOT NULL,
    origin_longitude DECIMAL(11,8)NOT NULL,
    destination_province VARCHAR(100),
    destination_city VARCHAR(100),
    destination_street VARCHAR(100),
    destination_latitude DECIMAL(10,8) NOT NULL,
    destination_longitude DECIMAL(11,8) NOT NULL,
    estimated_distance DECIMAL(10,2) NOT NULL,
    estimated_duration INT,
    calculated_price DECIMAL(10,2) NOT NULL, 
    allocated_discount DECIMAL(10,2) NOT NULL ,
    driver_rating_to_passenger INT ,
    passenger_rating_to_driver INT ,
    comment TEXT,
    ride_type VARCHAR(20) NOT NULL,
    requested_at DATETIME DEFAULT GETDATE(),
    accepted_at DATETIME,
    started_at DATETIME,
    completed_at DATETIME,
    ride_status VARCHAR(20)NOT NULL, -- درحال حرکت به مبدا ، درحال حرکت به مقصد ، تمام شده ، کنسل شده 
    cancelled_at DATETIME,
    cancel_reason VARCHAR(50),

    --TODO
)