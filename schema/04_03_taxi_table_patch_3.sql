USE mini_snapp;
GO


CREATE NONCLUSTERED INDEX IX_rides_passenger_id ON taxi.rides(passenger_id);
GO


CREATE NONCLUSTERED INDEX IX_rides_driver_id ON taxi.rides(driver_id);
GO


CREATE NONCLUSTERED INDEX IX_ride_offers_passenger_id ON taxi.ride_offers(passenger_id);
GO


CREATE NONCLUSTERED INDEX IX_ride_offer_candidates_driver_id ON taxi.ride_offer_candidates(driver_id);
GO