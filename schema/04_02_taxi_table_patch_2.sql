USE mini_snapp
GO

ALTER TABLE taxi.ride_offers
    ADD is_prepaid BIT NOT NULL DEFAULT 0;

GO

ALTER TABLE taxi.ride_offers
    ADD scheduled_start_time DATETIME NULL;

GO

ALTER TABLE taxi.rides
    ADD ride_payment_status VARCHAR(20) NOT NULL DEFAULT 'pending';

GO

ALTER TABLE taxi.rides
    ADD scheduled_start_time DATETIME NULL;

GO

ALTER TABLE taxi.rides
    ADD CONSTRAINT chk_rides_ride_payment_status
        CHECK (ride_payment_status IN ('pending', 'paid', 'refunded'));

GO

ALTER TABLE taxi.rides
    DROP CONSTRAINT chk_rides_status;

ALTER TABLE taxi.rides
    ADD CONSTRAINT chk_rides_status 
        CHECK (ride_status IN ('scheduled', 'to_origin', 'to_destination', 
            'completed', 'cancelled'));
GO