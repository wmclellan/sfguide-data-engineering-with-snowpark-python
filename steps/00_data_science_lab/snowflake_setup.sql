USE ROLE accountadmin;

-- Roles
SET MY_USER = CURRENT_USER();
CREATE ROLE IF NOT EXISTS HOL_ROLE;
GRANT ROLE HOL_ROLE TO ROLE SYSADMIN;
GRANT ROLE HOL_ROLE TO USER IDENTIFIER($MY_USER);
GRANT MONITOR EXECUTION ON ACCOUNT TO ROLE HOL_ROLE;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE HOL_ROLE;

-- Databases
CREATE DATABASE IF NOT EXISTS HOL_DB;
GRANT OWNERSHIP ON DATABASE HOL_DB TO ROLE HOL_ROLE;

-- Warehouses
CREATE OR REPLACE WAREHOUSE HOL_WH WAREHOUSE_SIZE = XSMALL, AUTO_SUSPEND = 300, AUTO_RESUME= TRUE;
GRANT OWNERSHIP ON WAREHOUSE HOL_WH TO ROLE HOL_ROLE;

-- create raw, harmonized, and analytics schemas
-- raw zone for data ingestion
USE ROLE HOL_ROLE;
USE WAREHOUSE HOL_WH;
USE DATABASE HOL_DB;
CREATE SCHEMA IF NOT EXISTS hol_db.raw;
-- harmonized zone for data processing
CREATE SCHEMA IF NOT EXISTS hol_db.harmonized;
-- analytics zone for development
CREATE SCHEMA IF NOT EXISTS hol_db.analytics;

-- create csv file format
CREATE OR REPLACE FILE FORMAT hol_db.raw.csv_ff 
type = 'csv';

-- create an external stage pointing to S3
CREATE OR REPLACE STAGE hol_db.raw.s3load
COMMENT = 'Quickstarts S3 Stage Connection'
url = 's3://sfquickstarts/frostbyte_tastybytes/'
file_format = hol_db.raw.csv_ff;

-- define shift sales table
CREATE OR REPLACE TABLE hol_db.raw.shift_sales(
	location_id NUMBER(19,0),
	city VARCHAR(16777216),
	date DATE,
	shift_sales FLOAT,
	shift VARCHAR(2),
	month NUMBER(2,0),
	day_of_week NUMBER(2,0),
	city_population NUMBER(38,0)
);

-- ingest from S3 into the shift sales table
COPY INTO hol_db.raw.shift_sales
FROM @hol_db.raw.s3load/analytics/shift_sales/;

-- join in SafeGraph data
CREATE OR REPLACE TABLE hol_db.harmonized.shift_sales
  AS
SELECT
    a.location_id,
    a.city,
    a.date,
    a.shift_sales,
    a.shift,
    a.month,
    a.day_of_week,
    a.city_population,
    b.latitude,
    b.longitude
FROM hol_db.raw.shift_sales a
JOIN frostbyte_safegraph.public.frostbyte_tb_safegraph_s b
ON a.location_id = b.location_id;

-- promote the harmonized table to the analytics layer for data science development
CREATE OR REPLACE VIEW hol_db.analytics.shift_sales_v
  AS
SELECT * FROM hol_db.harmonized.shift_sales;

-- view shift sales data
SELECT * FROM hol_db.analytics.shift_sales_v;