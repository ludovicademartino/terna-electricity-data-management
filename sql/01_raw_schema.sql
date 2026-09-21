-- =============================================================================
-- 01 - RAW SCHEMA
-- Data Management for Data Science - Homework 1
-- =============================================================================
-- Landing layer: one table per Terna CSV export, every column typed as TEXT.
-- The goal here is to ingest the files without a single parse error; typing,
-- domain checks and keys are deferred to the `clean` schema (02).
--
-- Load each CSV with, e.g.:
--   \copy raw.demand_data FROM 'data/FABBISOGNO.csv' WITH (FORMAT csv, HEADER true);
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS raw;

-- FABBISOGNO / demand per bidding zone (15-minute granularity)
CREATE TABLE raw.demand_data (
    date                   TEXT,
    total_load_mw          TEXT,
    forecast_total_load_mw TEXT,
    bidding_zone           TEXT
);

-- TRASMISSIONE / cross-border physical exchange with neighbouring countries
CREATE TABLE raw.transmission_data (
    date                       TEXT,
    country                    TEXT,
    import_mw                  TEXT,
    export_mw                  TEXT,
    scheduled_foreign_exchange TEXT
);

-- CONNESSIONI / RES grid-connection requests, by region and status
CREATE TABLE raw.connections (
    region            TEXT,
    plant_type        TEXT,
    source            TEXT,
    connection_status TEXT,
    capacity_mw       TEXT,
    num_requests      TEXT
);

-- MERCATO INFRAGIORNALIERO (MI) / intra-day transit limits, sessions CRIDA1-3
CREATE TABLE raw.intraday_market (
    date             TEXT,
    session          TEXT,
    zone_from        TEXT,
    zone_to          TEXT,
    transit_limit_mw TEXT
);

-- MSD / balancing market margins, sessions MSD1-6
CREATE TABLE raw.balancing_market (
    date      TEXT,
    session   TEXT,
    zone_from TEXT,
    zone_to   TEXT,
    margin_mw TEXT
);

-- MSD INPUT / forecast load fed into each balancing session
CREATE TABLE raw.balancing_market_input (
    date             TEXT,
    session          TEXT,
    zone             TEXT,
    forecast_load_mw TEXT
);

-- ADEGUATEZZA PREVISIONE / forecast available capacity, per macro-user
CREATE TABLE raw.adequacy_forecast (
    date                 TEXT,
    macroarea            TEXT,
    macrouser            TEXT,
    plant_type           TEXT,
    fuel                 TEXT,
    forecast_capacity_mw TEXT
);

-- ADEGUATEZZA CONSUNTIVO / actual available capacity by macroarea and fuel
CREATE TABLE raw.adequacy_actual (
    date                  TEXT,
    macroarea             TEXT,
    plant_type            TEXT,
    fuel                  TEXT,
    available_capacity_mw TEXT
);

-- GENERAZIONE / actual generation by primary source
CREATE TABLE raw.generation_data (
    date              TEXT,
    actual_generation TEXT,
    primary_source    TEXT
);

-- MGP / day-ahead market forecast transit limits
CREATE TABLE raw.day_ahead_market (
    date                      TEXT,
    zone_from                 TEXT,
    zone_to                   TEXT,
    forecast_transit_limit_mw TEXT
);
