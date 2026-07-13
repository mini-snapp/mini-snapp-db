USE mini_snapp;
GO

ALTER TABLE taxi.rides ALTER COLUMN comment NVARCHAR(MAX);
GO

ALTER TABLE taxi.taxi_logs ALTER COLUMN [description] NVARCHAR(MAX);
GO