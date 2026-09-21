-- =============================================================================
-- 03 - DIMENSION TABLES AND FOREIGN KEYS
-- Data Management for Data Science - Homework 1
-- =============================================================================
-- Two small dimension tables turn free-text labels into a controlled vocabulary:
--
--   clean.zone    -- every bidding zone and foreign border appearing in the data,
--                    flagged as Italian/foreign and aggregate/elementary
--   clean.source  -- every primary generation source, flagged as renewable
--
-- Every fact table then references them, so the DBMS enforces that no fact can
-- name a zone or a source that does not exist.
--
-- Run after 02_clean_schema.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- ZONE
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS clean.zone CASCADE;
CREATE TABLE clean.zone (
    zone_name    VARCHAR(30) PRIMARY KEY,
    is_italian   BOOLEAN NOT NULL,
    is_aggregate BOOLEAN NOT NULL DEFAULT FALSE
);

INSERT INTO clean.zone (zone_name, is_italian, is_aggregate) VALUES
    -- Italian bidding zones
    ('Calabria',      TRUE,  FALSE),
    ('Centre-North',  TRUE,  FALSE),
    ('Centre-South',  TRUE,  FALSE),
    ('North',         TRUE,  FALSE),
    ('Sardinia',      TRUE,  FALSE),
    ('Sicily',        TRUE,  FALSE),
    ('South',         TRUE,  FALSE),
    -- national aggregate
    ('Italy',         TRUE,  TRUE),
    -- foreign borders and virtual nodes
    ('Austria',       FALSE, FALSE),
    ('Austria 2',     FALSE, FALSE),
    ('France',        FALSE, FALSE),
    ('France 2',      FALSE, FALSE),
    ('Switzerland',   FALSE, FALSE),
    ('Switzerland 2', FALSE, FALSE),
    ('Slovenia',      FALSE, FALSE),
    ('Greece',        FALSE, FALSE),
    ('Greece 2',      FALSE, FALSE),
    ('Malta',         FALSE, FALSE),
    ('Montenegro',    FALSE, FALSE),
    ('Corsica',       FALSE, FALSE),
    ('Corsica AC',    FALSE, FALSE),
    ('BSP',           FALSE, FALSE),
    ('Coupling',      FALSE, FALSE);

-- -----------------------------------------------------------------------------
-- SOURCE
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS clean.source CASCADE;
CREATE TABLE clean.source (
    source_name VARCHAR(30) PRIMARY KEY,
    renewable   BOOLEAN NOT NULL
);

INSERT INTO clean.source (source_name, renewable) VALUES
    ('Geothermal',       TRUE),
    ('Hydro',            TRUE),
    ('Photovoltaic',     TRUE),
    ('Wind',             TRUE),
    ('Self-consumption', FALSE),
    ('Thermal',          FALSE);

-- -----------------------------------------------------------------------------
-- FOREIGN KEYS from the fact tables to the dimensions
-- -----------------------------------------------------------------------------
ALTER TABLE clean.demand_data
    ADD CONSTRAINT fk_demand_zone
    FOREIGN KEY (bidding_zone) REFERENCES clean.zone (zone_name);

ALTER TABLE clean.generation_data
    ADD CONSTRAINT fk_generation_source
    FOREIGN KEY (primary_source) REFERENCES clean.source (source_name);

ALTER TABLE clean.transmission_data
    ADD CONSTRAINT fk_transmission_country
    FOREIGN KEY (country) REFERENCES clean.zone (zone_name);

ALTER TABLE clean.day_ahead_market
    ADD CONSTRAINT fk_mgp_zone_from
    FOREIGN KEY (zone_from) REFERENCES clean.zone (zone_name);

ALTER TABLE clean.day_ahead_market
    ADD CONSTRAINT fk_mgp_zone_to
    FOREIGN KEY (zone_to) REFERENCES clean.zone (zone_name);

ALTER TABLE clean.intraday_market
    ADD CONSTRAINT fk_mi_zone_from
    FOREIGN KEY (zone_from) REFERENCES clean.zone (zone_name);

ALTER TABLE clean.intraday_market
    ADD CONSTRAINT fk_mi_zone_to
    FOREIGN KEY (zone_to) REFERENCES clean.zone (zone_name);

ALTER TABLE clean.balancing_market
    ADD CONSTRAINT fk_msd_zone_from
    FOREIGN KEY (zone_from) REFERENCES clean.zone (zone_name);

ALTER TABLE clean.balancing_market
    ADD CONSTRAINT fk_msd_zone_to
    FOREIGN KEY (zone_to) REFERENCES clean.zone (zone_name);

ALTER TABLE clean.balancing_market_input
    ADD CONSTRAINT fk_msd_input_zone
    FOREIGN KEY (zone) REFERENCES clean.zone (zone_name);

-- -----------------------------------------------------------------------------
-- HISTORICAL NOTE - superseded statements, kept for the record
-- -----------------------------------------------------------------------------
-- An earlier iteration of the pipeline loaded `date` as TEXT into the clean
-- layer and converted it afterwards, with one statement per table:
--
--   ALTER TABLE clean.demand_data
--       ALTER COLUMN date TYPE TIMESTAMP
--       USING TO_TIMESTAMP(date, 'DD/MM/YYYY HH24:MI:SS');
--   ...and the same for generation_data, transmission_data, day_ahead_market,
--      intraday_market, balancing_market, balancing_market_input,
--      adequacy_forecast and adequacy_actual.
--
-- These statements are no longer part of the pipeline: 02_clean_schema.sql now
-- declares `date` as TIMESTAMP and casts on INSERT, so re-running them against
-- the current schema would fail (the column is already a TIMESTAMP).
-- They are documented here only to show how the conversion step evolved.
