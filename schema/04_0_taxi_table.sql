USE mini_snapp

GO


CREATE TABLE taxi.drivers(
    driver_id INT IDENTITY(1,1) NOT NULL,
    user_id INT NOT NULL,
    national_id VARCHAR(15) NOT NULL,
    date_of_birth DATE NOT NULL , -- user for cal age
    driver_status VARCHAR(20) NOT NULL DEFAULT 'offline',
    gender VARCHAR(15),
    average_rating DECIMAL(3,2) DEFAULT 0.00,
    rating_count INT DEFAULT 0,
    activity_points INT DEFAULT 0, -- rank ba tarkib avg rating va activity_point hesab mishe

    CONSTRAINT pk_drivers_driver_id
        PRIMARY KEY (driver_id),

    CONSTRAINT fk_drivers_user_id
        FOREIGN KEY (user_id) REFERENCES core.users(user_id),

    CONSTRAINT uq_drivers_user_id
        UNIQUE (user_id),

    CONSTRAINT uq_drivers_national_id
        UNIQUE (national_id),

    CONSTRAINT chk_drivers_status
        CHECK (driver_status IN ('available','busy','offline','suspended')),

    CONSTRAINT chk_drivers_gender
        CHECK (gender IN ('male','female'))
);

GO

CREATE TABLE taxi.vehicles(
    vehicle_id INT IDENTITY(1,1) NOT NULL,
    owner_id INT NOT NULL,
    vehicle_type VARCHAR(20) NOT NULL,
    license_plate VARCHAR(20) NOT NULL,
    color VARCHAR(20) NOT NULL ,
    model_name VARCHAR(20) NOT NULL ,
    is_active_now BIT DEFAULT 0,

    CONSTRAINT pk_vehicles_vehicle_id
        PRIMARY KEY (vehicle_id),

    CONSTRAINT fk_vehicles_owner_id
        FOREIGN KEY (owner_id) REFERENCES taxi.drivers(driver_id),

    CONSTRAINT uq_vehicles_license_plate
        UNIQUE (license_plate),

    CONSTRAINT chk_vehicles_vehicle_type
        CHECK (vehicle_type IN ('economy','premium','suv','motorcycle','pickup','truck'))
)
GO

-- Defines which (vehicle_type, service_type) combinations are valid.
-- e.g. motorcycle can serve both passenger & cargo, truck only cargo, suv only passenger.
CREATE TABLE taxi.vehicle_type_services(
    vehicle_type VARCHAR(20) NOT NULL,
    service_type VARCHAR(20) NOT NULL,

    CONSTRAINT pk_vehicle_type_services
        PRIMARY KEY (vehicle_type, service_type),

    CONSTRAINT chk_vehicle_type_services_vehicle_type
        CHECK (vehicle_type IN ('economy','premium','suv','motorcycle','pickup','truck')),

    CONSTRAINT chk_vehicle_type_services_service_type
        CHECK (service_type IN ('passenger','cargo'))
);

GO

CREATE TABLE taxi.driver_wallets(
    driver_wallet_id INT IDENTITY(1,1) NOT NULL ,
    driver_id INT NOT NULL,
    balance DECIMAL(10,2) DEFAULT 0 ,

    CONSTRAINT pk_driver_wallets_driver_wallet_id
        PRIMARY KEY (driver_wallet_id),

    CONSTRAINT fk_driver_wallets_driver_id
        FOREIGN KEY (driver_id) REFERENCES taxi.drivers(driver_id),

    CONSTRAINT uq_driver_wallets_driver_id
        UNIQUE (driver_id)
);

GO

CREATE TABLE taxi.driver_locations(
    driver_id INT NOT NULL ,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    updated_at DATETIME,

    CONSTRAINT pk_driver_locations_driver_id
        PRIMARY KEY (driver_id),

    CONSTRAINT fk_driver_locations_driver_id
        FOREIGN KEY (driver_id) REFERENCES taxi.drivers(driver_id)
)

GO

CREATE TABLE taxi.driver_secondary_phones(
    driver_secondary_phone_id INT IDENTITY(1,1) NOT NULL,
    driver_id INT NOT NULL,
    phone_label VARCHAR(50),
    phone_number VARCHAR(15) NOT NULL,

    CONSTRAINT pk_driver_secondary_phones_driver_secondary_phone_id
        PRIMARY KEY (driver_secondary_phone_id),

    CONSTRAINT fk_driver_secondary_phones_id_driver_id
        FOREIGN KEY (driver_id) REFERENCES taxi.drivers(driver_id),

    CONSTRAINT uq_driver_secondary_phones_driver_id_phone_number
        UNIQUE (driver_id , phone_number),

    CONSTRAINT uq_driver_secondary_phones__phone_number
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
    origin_latitude DECIMAL(10,8) NOT NULL,
    origin_longitude DECIMAL(11,8) NOT NULL,
    destination_province VARCHAR(100),
    destination_city VARCHAR(100),
    destination_street VARCHAR(100),
    destination_latitude DECIMAL(10,8) NOT NULL,
    destination_longitude DECIMAL(11,8) NOT NULL,
    estimated_distance DECIMAL(10,2) NOT NULL,
    estimated_duration INT,
    calculated_price DECIMAL(10,2) NOT NULL,
    allocated_discount DECIMAL(10,2) NOT NULL DEFAULT 0,
    driver_rating_to_passenger INT ,
    passenger_rating_to_driver INT ,
    comment TEXT,
    service_type VARCHAR(20) NOT NULL, -- passenger / cargo, ride ba in vehicle barash chikar mishe
    requested_at DATETIME,
    accepted_at DATETIME,
    started_at DATETIME,
    completed_at DATETIME,
    ride_status VARCHAR(20) NOT NULL, -- درحال حرکت به مبدا ، درحال حرکت به مقصد ، تمام شده ، کنسل شده
    cancelled_at DATETIME,
    cancel_reason VARCHAR(50),

    CONSTRAINT pk_rides_ride_id
        PRIMARY KEY (ride_id),

    CONSTRAINT fk_rides_passenger_id
        FOREIGN KEY (passenger_id) REFERENCES core.users(user_id),

    CONSTRAINT fk_rides_driver_id
        FOREIGN KEY (driver_id) REFERENCES taxi.drivers(driver_id),

    CONSTRAINT fk_rides_vehicle_id
        FOREIGN KEY (vehicle_id) REFERENCES taxi.vehicles(vehicle_id),

    CONSTRAINT chk_rides_service_type
        CHECK (service_type IN ('passenger','cargo')),

    CONSTRAINT chk_rides_status
        CHECK (ride_status IN ('to_origin','to_destination','completed','cancelled')),

    CONSTRAINT chk_rides_driver_rating
        CHECK (driver_rating_to_passenger IS NULL OR driver_rating_to_passenger BETWEEN 1 AND 5),

    CONSTRAINT chk_rides_passenger_rating
        CHECK (passenger_rating_to_driver IS NULL OR passenger_rating_to_driver BETWEEN 1 AND 5),

    CONSTRAINT chk_rides_time_order
        CHECK (
            (accepted_at IS NULL OR requested_at IS NULL OR accepted_at >= requested_at) AND
            (started_at IS NULL OR accepted_at IS NULL OR started_at >= accepted_at) AND
            (completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at)
        )

);

GO

CREATE TABLE taxi.ride_payments(
    ride_id INT NOT NULL ,
    ride_payment_transaction_id INT NOT NULL,

    CONSTRAINT pk_ride_payments_ride_id
        PRIMARY KEY (ride_id),

    CONSTRAINT fk_ride_payments_ride_id
        FOREIGN KEY (ride_id) REFERENCES taxi.rides(ride_id),

    CONSTRAINT fk_ride_payment_ride_transaction_id
        FOREIGN KEY (ride_payment_transaction_id) REFERENCES core.transactions(transaction_id),

    CONSTRAINT uq_ride_payments_transaction_id
        UNIQUE (ride_payment_transaction_id)
);

GO

CREATE TABLE taxi.passenger_stats(
    user_id INT NOT NULL ,
    average_score DECIMAL(3,2) DEFAULT 0.00,
    score_count INT DEFAULT 0,
    activity_score INT DEFAULT 0, -- rank ba activity_score , average_score sakhte mishe

    CONSTRAINT pk_passenger_stats_user_id
        PRIMARY KEY (user_id),

    CONSTRAINT fk_passenger_stats_user_id
        FOREIGN KEY (user_id) REFERENCES core.users(user_id)
)

GO

CREATE TABLE taxi.taxi_logs(
        taxi_log_id INT IDENTITY(1,1) NOT NULL,
        actor_id INT ,
        operation_type VARCHAR(10) NOT NULL,
        target_table VARCHAR(50) NOT NULL,
        target_id VARCHAR(50) NOT NULL,
        old_value NVARCHAR(MAX) ,
        new_value NVARCHAR(MAX) ,
        create_at DATETIME DEFAULT GETDATE(),
        [description] TEXT ,
        driver_id INT ,
        ride_id INT ,

        CONSTRAINT pk_taxi_logs
            PRIMARY KEY (taxi_log_id),

        CONSTRAINT fk_taxi_logs_actor_id
            FOREIGN KEY (actor_id) REFERENCES core.users(user_id),

        CONSTRAINT chk_taxi_logs_operation_type
            CHECK (operation_type IN ('insert','update','delete')),

        CONSTRAINT fk_taxi_logs_driver_id
            FOREIGN KEY (driver_id) REFERENCES taxi.drivers(driver_id),

        CONSTRAINT fk_taxi_logs_ride_id
            FOREIGN KEY (ride_id) REFERENCES taxi.rides(ride_id)

);

GO

CREATE TABLE taxi.pricing_parameters(
    pricing_parameter_id INT IDENTITY(1,1) NOT NULL ,
    vehicle_type VARCHAR(20) NOT NULL,
    service_type VARCHAR(20) NOT NULL,
    base_fare DECIMAL(10,2) NOT NULL ,
    price_per_km DECIMAL(10,2) NOT NULL,
    price_per_minute DECIMAL(10,2) NOT NULL,
    effective_from DATETIME DEFAULT GETDATE(),
    effective_to DATETIME ,

    CONSTRAINT pk_pricing_parameters_pricing_parameter_id
        PRIMARY KEY (pricing_parameter_id),

    CONSTRAINT fk_pricing_parameters_vehicle_service
        FOREIGN KEY (vehicle_type, service_type) REFERENCES taxi.vehicle_type_services(vehicle_type, service_type),

    CONSTRAINT chk_pricing_parameters_time_check
        CHECK (effective_to IS NULL OR effective_from < effective_to)
)

GO

CREATE TABLE taxi.ride_offers(
    ride_offer_id INT IDENTITY(1,1) NOT NULL ,
    passenger_id INT NOT NULL ,
    origin_latitude DECIMAL(10,8) NOT NULL ,
    origin_longitude DECIMAL (11, 8) NOT NULL ,
    destination_latitude DECIMAL (10 , 8) NOT NULL ,
    destination_longitude DECIMAL (11, 8) NOT NULL ,
    calculated_price DECIMAL(10 , 2) NOT NULL ,
    vehicle_type VARCHAR(20) NOT NULL ,
    service_type VARCHAR(20) NOT NULL ,
    requested_at DATETIME DEFAULT GETDATE(),
    expires_at DATETIME NOT NULL,

    CONSTRAINT pk_ride_offers_ride_offer_id
        PRIMARY KEY (ride_offer_id),

    CONSTRAINT fk_ride_offers_passenger_id
        FOREIGN KEY (passenger_id) REFERENCES core.users(user_id),

    CONSTRAINT fk_ride_offers_vehicle_service
        FOREIGN KEY (vehicle_type, service_type) REFERENCES taxi.vehicle_type_services(vehicle_type, service_type),

    CONSTRAINT chk_ride_offers_time_check
        CHECK (requested_at < expires_at)
);

GO

CREATE TABLE taxi.ride_offer_candidates(
    ride_offer_candidate_id INT IDENTITY(1,1) NOT NULL ,
    offer_id INT NOT NULL ,
    driver_id INT NOT NULL ,
    notified_at DATETIME DEFAULT GETDATE(),
    responded_at DATETIME ,
    response_status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending , accepted , rejected , timeout

    CONSTRAINT pk_ride_offer_candidates_ride_offer_candidate_id
        PRIMARY KEY(ride_offer_candidate_id),

    CONSTRAINT fk_ride_offer_candidates_offer_id
        FOREIGN KEY (offer_id) REFERENCES taxi.ride_offers(ride_offer_id),

    CONSTRAINT fk_ride_offer_candidates_driver_id
        FOREIGN KEY (driver_id) REFERENCES taxi.drivers(driver_id),

    CONSTRAINT uq_ride_offer_candidates_offer_driver
        UNIQUE (offer_id, driver_id),

    CONSTRAINT chk_ride_offer_candidates_response_status
        CHECK (response_status IN ('pending','accepted','rejected','timeout'))
);

GO