-- =============================================================================
-- 05 - QUERY EVALUATION AND OPTIMIZATION
-- Data Management for Data Science - Homework 2
-- =============================================================================
-- Four of the ten queries pose a performance problem to PostgreSQL. For each one
-- this script shows the auxiliary structures and the rewrite that produce the
-- fast plan. The slow versions are in 04_queries.sql.
--
--   Query  Bottleneck                          Technique                            Slow     Fast
--   -----  ----------------------------------  -----------------------------------  ------   ------
--   Q3     correlated AVG per country          materialized view + index             9.7 s   15 ms
--   Q8     correlated daily AVG on Italy       precomputed table + stored date_only  2.9 s   19 ms
--   Q9     NOT EXISTS anti-join on intraday    composite B+-tree indexes             1.3 s   958 ms
--   Q10    doubly nested correlated AVG        materialized critical_hours + index   172 ms  13 ms
--
-- Measured with EXPLAIN ANALYZE on the dataset described in the README.
-- Run each block, then re-run the corresponding query from 04_queries.sql to
-- compare the plans.
-- =============================================================================


-- #############################################################################
-- QUERY 3 - Countries with a net import balance
-- #############################################################################
-- Problem: the sub-query computing each country's average import is correlated,
-- so the inner query is executed once for every tuple of the outer query.
-- Fix: materialise the per-country average once, and index the join column.
-- Cost: from "inner query per outer tuple" to an indexed lookup, D * log2(B).

CREATE MATERIALIZED VIEW clean.mv_country_avg_import AS
SELECT
    country,
    AVG(import_mw) AS avg_import_country
FROM clean.transmission_data
GROUP BY country;

CREATE INDEX idx_mv_country_avg_country
    ON clean.mv_country_avg_import (country);

-- Fast version
SELECT
    t.country,
    AVG(t.import_mw)                  AS avg_import_mw,
    AVG(t.scheduled_foreign_exchange) AS avg_balance_mw,
    MAX(t.import_mw)                  AS peak_import_mw,
    COUNT(*)                          AS num_high_import_hours
FROM clean.transmission_data t, clean.mv_country_avg_import m
WHERE t.country = m.country
  AND t.import_mw > 0
  AND t.import_mw > m.avg_import_country
GROUP BY t.country
HAVING AVG(t.scheduled_foreign_exchange) > 0
ORDER BY avg_balance_mw DESC, peak_import_mw DESC;


-- #############################################################################
-- QUERY 8 - Renewable generation on daily peak hours
-- #############################################################################
-- Problem: the threshold is a per-day average recomputed for every tuple, and
-- DATE(date) on both sides prevents any index from being used.
-- Fix: store the day as a real column, precompute the daily average once, and
-- index both join columns.

-- 1. Materialise the day, so the join is on a plain column and not on DATE(...)
ALTER TABLE clean.demand_data ADD COLUMN date_only DATE;
UPDATE clean.demand_data SET date_only = DATE(date);

-- 2. Precompute the daily national average
DROP TABLE IF EXISTS clean.daily_italy_avg_load;
CREATE TABLE clean.daily_italy_avg_load AS
SELECT
    DATE(date)         AS date_only,
    AVG(total_load_mw) AS avg_daily_load_italy
FROM clean.demand_data
WHERE bidding_zone = 'Italy'
GROUP BY DATE(date);

-- 3. Index both sides of the new join
CREATE INDEX idx_daily_italy_date ON clean.daily_italy_avg_load (date_only);
CREATE INDEX idx_demand_date_only ON clean.demand_data (date_only);

-- Fast version
SELECT
    g.primary_source,
    AVG(g.actual_generation) AS avg_generation_peak_mw,
    MIN(g.actual_generation) AS min_generation_peak_mw,
    MAX(g.actual_generation) AS max_generation_peak_mw,
    COUNT(*)                 AS num_peak_observations
FROM clean.generation_data g, clean.demand_data d, clean.daily_italy_avg_load da
WHERE g.date = d.date
  AND d.bidding_zone = 'Italy'
  AND d.date_only = da.date_only
  AND g.primary_source IN (
        SELECT source_name
        FROM clean.source
        WHERE renewable = TRUE
  )
  AND d.total_load_mw > da.avg_daily_load_italy
GROUP BY g.primary_source
ORDER BY avg_generation_peak_mw DESC;


-- #############################################################################
-- QUERY 9 - MSD6 margins not covered by intra-day limits
-- #############################################################################
-- Problem: the NOT EXISTS anti-join scans clean.intraday_market (67k rows) once
-- per candidate row of the balancing market; cost in the order of B(D + RC).
-- Fix: composite B+-tree indexes covering exactly the anti-join predicate, so
-- the probe becomes D * log2(B). The query text itself is unchanged.

CREATE INDEX idx_bal_market   ON clean.balancing_market (session, zone_from, zone_to);
CREATE INDEX idx_intra_market ON clean.intraday_market  (zone_from, zone_to, transit_limit_mw);
CREATE INDEX idx_dayah_zones  ON clean.day_ahead_market (zone_from, zone_to);

-- Then re-run QUERY 9 from 04_queries.sql: 1.3 s -> 958 ms.


-- #############################################################################
-- QUERY 10 - Generation during critical hours
-- #############################################################################
-- Problem: two levels of correlation. For every generation row the EXISTS is
-- evaluated, and inside it a second sub-query recomputes the average error of
-- that same timestamp.
-- Fix: the set of critical timestamps does not depend on the outer row, so it
-- can be materialised once into a table and indexed.

DROP TABLE IF EXISTS clean.critical_hours;
CREATE TABLE clean.critical_hours AS
SELECT DISTINCT d.date
FROM clean.demand_data d,
     (
        SELECT
            date,
            AVG(ABS(total_load_mw - forecast_total_load_mw)) AS avg_err
        FROM clean.demand_data
        WHERE bidding_zone <> 'Italy'
        GROUP BY date
     ) m
WHERE d.date = m.date
  AND d.bidding_zone <> 'Italy'
  AND ABS(d.total_load_mw - d.forecast_total_load_mw) > 2 * m.avg_err;

CREATE INDEX idx_crit_hours ON clean.critical_hours (date);

-- Fast version: the nested EXISTS collapses into a plain join
SELECT
    g.primary_source,
    AVG(g.actual_generation) AS avg_generation_critical_mw,
    MAX(g.actual_generation) AS peak_generation_critical_mw,
    COUNT(*)                 AS num_critical_obs
FROM clean.generation_data g, clean.critical_hours c
WHERE g.date = c.date
GROUP BY g.primary_source
ORDER BY avg_generation_critical_mw DESC;


-- #############################################################################
-- TEARDOWN - drop the auxiliary structures
-- #############################################################################
-- Used during the presentation to switch back to the slow plans and show the
-- two executions side by side.

-- DROP INDEX IF EXISTS clean.idx_mv_country_avg_country;
-- DROP MATERIALIZED VIEW IF EXISTS clean.mv_country_avg_import;

-- DROP INDEX IF EXISTS clean.idx_daily_italy_date;
-- DROP INDEX IF EXISTS clean.idx_demand_date_only;
-- DROP TABLE IF EXISTS clean.daily_italy_avg_load;

-- DROP INDEX IF EXISTS clean.idx_bal_market;
-- DROP INDEX IF EXISTS clean.idx_intra_market;
-- DROP INDEX IF EXISTS clean.idx_dayah_zones;

-- DROP INDEX IF EXISTS clean.idx_crit_hours;
-- DROP TABLE IF EXISTS clean.critical_hours;
