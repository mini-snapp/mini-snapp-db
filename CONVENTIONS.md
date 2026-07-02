# Naming Conventions

## Tables
- Plural, lowercase, snake_case

## Primary Keys
- Format: table_name + _id

## Foreign Keys
- Same name as the referenced primary key

## Boolean Columns
- Prefix: is_ or has_

## Object Prefixes
- Views:             vw_
- Functions:         fn_
- Stored Procedures: sp_
- Triggers:          trg_

## Trigger Naming
- Format: trg_ + table + event

## Constraints
- Format: type_table_column

## Schemas
- core:  shared or core infrastructure
- food:  food ordering service
- taxi:  taxi service
- 
## Data Types

Money:        DECIMAL(10,2)
Percentage:   DECIMAL(5,2)
Latitude:     DECIMAL(10,8)
Longitude:    DECIMAL(11,8)
first_name, last_name         VARCHAR(50)
username                      VARCHAR(50)
email                         VARCHAR(100)
password (hashed)             VARCHAR(255)
phone (registration/business/secondary)  VARCHAR(15)
national_id                   VARCHAR(15)
license_plate                 VARCHAR(15)
address_name, city, province, street     VARCHAR(100)
code (coupon)                 VARCHAR(20)
status, type, role_name, operation_type  VARCHAR(20)
title (complaint)             VARCHAR(150)
