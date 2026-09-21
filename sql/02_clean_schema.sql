-- =============================================================================
-- 02 - CLEAN SCHEMA
-- Data Management for Data Science - Homework 1
-- =============================================================================
-- Curated layer. Every table is rebuilt from `raw` with:
--   * proper types      -- TIMESTAMP, NUMERIC, VARCHAR instead of TEXT
--   * integrity checks  -- NOT NULL, non-negative quantities, enumerated sessions
--   * composite keys    -- the natural identifier of each fact (date, zone, ...)
--
-- Every INSERT filters out the "Applied filters ..." footer row that the Terna
-- Download Center appends to each export.
--
-- Run after 01_raw_schema.sql and the CSV load.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS clean;

-- -----------------------------------------------------------------------------
-- FABBISOGNO / demand
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS clean.demand_data;
CREATE TABLE clean.demand_data (
    date                   TIMESTAMP   NOT NULL,
    total_load_mw          NUMERIC     NOT NULL CHECK (total_load_mw >= 0),
    forecast_total_load_mw NUMERIC     NOT NULL CHECK (forecast_total_load_mw >= 0),
    bidding_zone           VARCHAR(30) NOT NULL,
    PRIMARY KEY (date, bidding_zone)
);

INSERT INTO clean.demand_data
SELECT
    TO_TIMESTAMP(date, 'DD/MM/YYYY HH24:MI:SS'),
    total_load_mw::NUMERIC,
    forecast_total_load_mw::NUMERIC,
    bidding_zone
FROM raw.demand_data
WHERE date NOT LIKE 'Applied filters%';

-- -----------------------------------------------------------------------------
-- TRASMISSIONE / cross-border exchange
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS clean.transmission_data;
CREATE TABLE clean.transmission_data (
    date                       TIMESTAMP   NOT NULL,
    country                    VARCHAR(30) NOT NULL,
    import_mw                  NUMERIC     NOT NULL CHECK (import_mw >= 0),
    export_mw                  NUMERIC     NOT NULL CHECK (export_mw >= 0),
    scheduled_foreign_exchange NUMERIC     NOT NULL,
    PRIMARY KEY (date, country)
);

INSERT INTO clean.transmission_data
SELECT
    TO_TIMESTAMP(date, 'DD/MM/YYYY HH24:MI:SS'),
    country,
    import_mw::NUMERIC,
    export_mw::NUMERIC,
    scheduled_foreign_exchange::NUMERIC
FROM raw.transmission_data
WHERE date NOT LIKE 'Applied filters%';

-- -----------------------------------------------------------------------------
-- CONNESSIONI / grid-connection requests
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS clean.connections;
CREATE TABLE clean.connections (
    region            VARCHAR(30) NOT NULL,
    plant_type        VARCHAR(30) NOT NULL,
    source            VARCHAR(30) NOT NULL,
    connection_status VARCHAR(40) NOT NULL,
    capacity_mw       NUMERIC     NOT NULL CHECK (capacity_mw >= 0),
    num_requests      INTEGER     NOT NULL CHECK (num_requests >= 0),
    PRIMARY KEY (region, plant_type, source, connection_status)
);

INSERT INTO clean.connections
SELECT
    region,
    plant_type,
    source,
    connection_status,
    capacity_mw::NUMERIC,
    num_requests::NUMERIC::INTEGER
FROM raw.connections
WHERE region NOT LIKE 'Applied filters%';

-- -----------------------------------------------------------------------------
-- MERCATO INFRAGIORNALIERO (MI) / intra-day transit limits
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS clean.intraday_market;
CREATE TABLE clean.intraday_market (
    date             TIMESTAMP   NOT NULL,
    session          VARCHAR(10) NOT NULL CHECK (session IN ('CRIDA1', 'CRIDA2', 'CRIDA3')),
    zone_from        VARCHAR(30) NOT NULL,
    zone_to          VARCHAR(30) NOT NULL,
    transit_limit_mw NUMERIC     NOT NULL,
    PRIMARY KEY (date, session, zone_from, zone_to)
);

INSERT INTO clean.intraday_market
SELECT
    TO_TIMESTAMP(date, 'DD/MM/YYYY HH24:MI:SS'),
    session,
    zone_from,
    zone_to,
    transit_limit_mw::NUMERIC
FROM raw.intraday_market
WHERE date NOT LIKE 'Applied filters%';

-- -----------------------------------------------------------------------------
-- MSD / balancing market margins
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS clean.balancing_market;
CREATE TABLE clean.balancing_market (
    date      TIMESTAMP   NOT NULL,
    session   VARCHAR(10) NOT NULL CHECK (session IN ('MSD1', 'MSD2', 'MSD3', 'MSD4', 'MSD5', 'MSD6')),
    zone_from VARCHAR(30) NOT NULL,
    zone_to   VARCHAR(30) NOT NULL,
    margin_mw NUMERIC     NOT NULL,
    PRIMARY KEY (date, session, zone_from, zone_to)
);

INSERT INTO clean.balancing_market
SELECT
    TO_TIMESTAMP(date, 'DD/MM/YYYY HH24:MI:SS'),
    session,
    zone_from,
    zone_to,
    margin_mw::NUMERIC
FROM raw.balancing_market
WHERE date NOT LIKE 'Applied filters%';

-- -----------------------------------------------------------------------------
-- MSD INPUT / forecast load per balancing session
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS clean.balancing_market_input;
CREATE TABLE clean.balancing_market_input (
    date             TIMESTAMP   NOT NULL,
    session          VARCHAR(10) NOT NULL CHECK (session IN ('MSD1', 'MSD2', 'MSD3', 'MSD4', 'MSD5', 'MSD6')),
    zone             VARCHAR(30) NOT NULL,
    forecast_load_mw NUMERIC     NOT NULL CHECK (forecast_load_mw >= 0),
    PRIMARY KEY (date, session, zone)
);

INSERT INTO clean.balancing_market_input
SELECT
    TO_TIMESTAMP(date, 'DD/MM/YYYY HH24:MI:SS'),
    session,
    zone,
    forecast_load_mw::NUMERIC
FROM raw.balancing_market_input
WHERE date NOT LIKE 'Applied filters%';

-- -----------------------------------------------------------------------------
-- ADEGUATEZZA PREVISIONE / forecast available capacity
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS clean.adequacy_forecast;
CREATE TABLE clean.adequacy_forecast (
    date                 TIMESTAMP   NOT NULL,
    macroarea            VARCHAR(20) NOT NULL CHECK (macroarea IN ('Nord', 'Sud_Isole')),
    macrouser            VARCHAR(20) NOT NULL,
    plant_type           VARCHAR(30) NOT NULL,
    fuel                 VARCHAR(30) NOT NULL,
    forecast_capacity_mw NUMERIC     NOT NULL CHECK (forecast_capacity_mw >= 0),
    PRIMARY KEY (date, macroarea, macrouser, plant_type, fuel)
);

INSERT INTO clean.adequacy_forecast
SELECT
    TO_TIMESTAMP(date, 'DD/MM/YYYY HH24:MI:SS'),
    macroarea,
    macrouser,
    plant_type,
    fuel,
    forecast_capacity_mw::NUMERIC
FROM raw.adequacy_forecast
WHERE date NOT LIKE 'Applied filters%';

-- -----------------------------------------------------------------------------
-- ADEGUATEZZA CONSUNTIVO / actual available capacity
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS clean.adequacy_actual;
CREATE TABLE clean.adequacy_actual (
    date                  TIMESTAMP   NOT NULL,
    macroarea             VARCHAR(20) NOT NULL CHECK (macroarea IN ('Nord', 'Sud_Isole')),
    plant_type            VARCHAR(30) NOT NULL,
    fuel                  VARCHAR(30) NOT NULL,
    available_capacity_mw NUMERIC     NOT NULL CHECK (available_capacity_mw >= 0),
    PRIMARY KEY (date, macroarea, plant_type, fuel)
);

INSERT INTO clean.adequacy_actual
SELECT
    TO_TIMESTAMP(date, 'DD/MM/YYYY HH24:MI:SS'),
    macroarea,
    plant_type,
    fuel,
    available_capacity_mw::NUMERIC
FROM raw.adequacy_actual
WHERE date NOT LIKE 'Applied filters%';

-- -----------------------------------------------------------------------------
-- GENERAZIONE / actual generation by primary source
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS clean.generation_data;
CREATE TABLE clean.generation_data (
    date              TIMESTAMP   NOT NULL,
    actual_generation NUMERIC     NOT NULL CHECK (actual_generation >= 0),
    primary_source    VARCHAR(30) NOT NULL,
    PRIMARY KEY (date, primary_source)
);

INSERT INTO clean.generation_data
SELECT
    TO_TIMESTAMP(date, 'DD/MM/YYYY HH24:MI:SS'),
    actual_generation::NUMERIC,
    primary_source
FROM raw.generation_data
WHERE date NOT LIKE 'Applied filters%';

-- -----------------------------------------------------------------------------
-- MGP / day-ahead market forecast transit limits
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS clean.day_ahead_market;
CREATE TABLE clean.day_ahead_market (
    date                      TIMESTAMP   NOT NULL,
    zone_from                 VARCHAR(30) NOT NULL,
    zone_to                   VARCHAR(30) NOT NULL,
    forecast_transit_limit_mw NUMERIC     NOT NULL,
    PRIMARY KEY (date, zone_from, zone_to)
);

INSERT INTO clean.day_ahead_market
SELECT
    TO_TIMESTAMP(date, 'DD/MM/YYYY HH24:MI:SS'),
    zone_from,
    zone_to,
    forecast_transit_limit_mw::NUMERIC
FROM raw.day_ahead_market
WHERE date NOT LIKE 'Applied filters%';
