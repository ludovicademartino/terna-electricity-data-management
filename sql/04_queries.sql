-- =============================================================================
-- 04 - ANALYTICAL QUERIES
-- Data Management for Data Science - Homework 1
-- =============================================================================
-- Ten queries over the `clean` schema. Together they sketch a small study of the
-- Italian power system: where the demand forecast is least accurate, how
-- renewables behave at peak, which foreign exchanges weigh most, and where the
-- grid comes under stress.
--
-- Between them they cover the SQL constructs required by the assignment:
-- joins, aggregation, GROUP BY / HAVING, scalar and correlated sub-queries,
-- IN sub-queries, negated sub-queries (NOT EXISTS), derived tables and UNION.
--
-- Queries marked (*) are the ones analysed and optimised in Homework 2; their
-- fast rewrites live in 05_optimizations.sql.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- QUERY 1 - Daily forecast error per zone
-- Days and zones whose mean absolute forecast error exceeds the overall mean.
-- Constructs: aggregation, GROUP BY, HAVING with a scalar sub-query.
-- -----------------------------------------------------------------------------
SELECT
    DATE(date) AS date,
    bidding_zone,
    AVG(forecast_total_load_mw)                        AS avg_forecast_mw,
    AVG(total_load_mw)                                 AS avg_load_mw,
    AVG(ABS(total_load_mw - forecast_total_load_mw))   AS absolute_avg_error_mw
FROM clean.demand_data
WHERE bidding_zone <> 'Italy'
GROUP BY date, bidding_zone
HAVING AVG(ABS(total_load_mw - forecast_total_load_mw)) > (
    SELECT AVG(ABS(total_load_mw - forecast_total_load_mw))
    FROM clean.demand_data
    WHERE bidding_zone <> 'Italy'
)
ORDER BY AVG(ABS(total_load_mw - forecast_total_load_mw)) DESC, date;


-- -----------------------------------------------------------------------------
-- QUERY 2 - Renewables during high-load hours
-- How each renewable source produces in the hours when national demand is above
-- its own average.
-- Constructs: join, IN sub-query on a dimension table, scalar sub-query.
-- -----------------------------------------------------------------------------
SELECT
    g.primary_source,
    AVG(g.actual_generation) AS avg_generation_mw,
    MIN(g.actual_generation) AS min_generation_mw,
    MAX(g.actual_generation) AS max_generation_mw,
    SUM(g.actual_generation) AS total_generation_mw
FROM clean.generation_data g, clean.demand_data d
WHERE g.date = d.date
  AND d.bidding_zone = 'Italy'
  AND g.primary_source IN (
        SELECT source_name
        FROM clean.source
        WHERE renewable = TRUE
  )
  AND d.total_load_mw > (
        SELECT AVG(d2.total_load_mw)
        FROM clean.demand_data AS d2
        WHERE d2.bidding_zone = 'Italy'
  )
GROUP BY g.primary_source
ORDER BY SUM(g.actual_generation) DESC;


-- -----------------------------------------------------------------------------
-- QUERY 3 (*) - Countries with a net import balance
-- Restricted to the hours in which each country imports above its own average.
-- Constructs: CORRELATED sub-query in WHERE, aggregation, HAVING.
-- Performance: the correlated AVG is re-evaluated per row -> see 05.
-- -----------------------------------------------------------------------------
SELECT
    t.country,
    AVG(t.import_mw)                  AS avg_import_mw,
    AVG(t.scheduled_foreign_exchange) AS avg_balance_mw,
    MAX(t.import_mw)                  AS peak_import_mw,
    COUNT(*)                          AS num_high_import_hours
FROM clean.transmission_data t
WHERE t.import_mw > 0
  AND t.import_mw > (
        SELECT AVG(t2.import_mw)
        FROM clean.transmission_data t2
        WHERE t2.country = t.country
  )
GROUP BY t.country
HAVING AVG(t.scheduled_foreign_exchange) > 0
ORDER BY avg_balance_mw DESC, peak_import_mw DESC;


-- -----------------------------------------------------------------------------
-- QUERY 4 - MSD margins against forecast load
-- Zone pairs and balancing sessions whose average margin is below the global
-- average, i.e. the structurally tight links of the grid.
-- Constructs: join on a composite key, aggregation, HAVING with a sub-query.
-- This is the query reproduced as a graph in Neo4j and drawn on a map.
-- -----------------------------------------------------------------------------
SELECT
    b.zone_from,
    b.zone_to,
    b.session,
    AVG(b.margin_mw)        AS avg_margin_mw,
    AVG(i.forecast_load_mw) AS forecast_avg_load_mw
FROM clean.balancing_market b, clean.balancing_market_input i
WHERE b.date = i.date
  AND b.session = i.session
GROUP BY b.zone_from, b.zone_to, b.session
HAVING AVG(b.margin_mw) < (
    SELECT AVG(margin_mw)
    FROM clean.balancing_market
)
ORDER BY AVG(b.margin_mw) ASC, AVG(i.forecast_load_mw) DESC;


-- -----------------------------------------------------------------------------
-- QUERY 5 - Below-average available capacity per macroarea
-- Plant type / fuel combinations that underperform the average of their own
-- macroarea.
-- Constructs: derived table (inline view), JOIN, GROUP BY, HAVING on a joined
-- aggregate.
-- -----------------------------------------------------------------------------
SELECT
    a1.macroarea,
    a1.plant_type,
    a1.fuel,
    AVG(a1.available_capacity_mw) AS avg_available_capacity_mw,
    m.avg_capacity_macroarea
FROM clean.adequacy_actual a1
JOIN (
    SELECT
        a2.macroarea,
        AVG(a2.available_capacity_mw) AS avg_capacity_macroarea
    FROM clean.adequacy_actual a2
    GROUP BY a2.macroarea
) m
  ON a1.macroarea = m.macroarea
GROUP BY a1.macroarea, a1.plant_type, a1.fuel, m.avg_capacity_macroarea
HAVING AVG(a1.available_capacity_mw) < m.avg_capacity_macroarea
ORDER BY a1.macroarea, AVG(a1.available_capacity_mw) ASC;


-- -----------------------------------------------------------------------------
-- QUERY 6 - North vs South-and-Islands comparison
-- Load level, volatility and forecast accuracy of the two macro-areas.
-- Constructs: UNION of two aggregate blocks, derived measure (load range).
-- -----------------------------------------------------------------------------
SELECT
    'North' AS macro_area,
    AVG(total_load_mw)                               AS avg_load_mw,
    MIN(total_load_mw)                               AS min_load_mw,
    MAX(total_load_mw)                               AS max_load_mw,
    MAX(total_load_mw) - MIN(total_load_mw)          AS load_range_mw,
    AVG(forecast_total_load_mw)                      AS avg_forecast_mw,
    AVG(ABS(total_load_mw - forecast_total_load_mw)) AS avg_forecast_error_mw
FROM clean.demand_data
WHERE bidding_zone IN ('North', 'Centre-North')

UNION

SELECT
    'South and Islands' AS macro_area,
    AVG(total_load_mw)                               AS avg_load_mw,
    MIN(total_load_mw)                               AS min_load_mw,
    MAX(total_load_mw)                               AS max_load_mw,
    MAX(total_load_mw) - MIN(total_load_mw)          AS load_range_mw,
    AVG(forecast_total_load_mw)                      AS avg_forecast_mw,
    AVG(ABS(total_load_mw - forecast_total_load_mw)) AS avg_forecast_error_mw
FROM clean.demand_data
WHERE bidding_zone IN ('Centre-South', 'South', 'Calabria', 'Sicily', 'Sardinia')

ORDER BY load_range_mw DESC, avg_load_mw DESC;


-- -----------------------------------------------------------------------------
-- QUERY 7 - Connection requests never reaching a final contract
-- Region / source pairs with pending capacity and no signed contract at all.
-- Constructs: NEGATED sub-query (NOT EXISTS), aggregation.
-- -----------------------------------------------------------------------------
SELECT
    c.region,
    c.source,
    SUM(c.capacity_mw)  AS total_capacity_requested_mw,
    SUM(c.num_requests) AS total_number_requests
FROM clean.connections c
WHERE c.connection_status <> 'STMD/Contratti'
  AND NOT EXISTS (
        SELECT *
        FROM clean.connections c2
        WHERE c2.region = c.region
          AND c2.source = c.source
          AND c2.connection_status = 'STMD/Contratti'
  )
GROUP BY c.region, c.source
ORDER BY SUM(c.capacity_mw) DESC;


-- -----------------------------------------------------------------------------
-- QUERY 8 (*) - Renewable generation on daily peak hours
-- Like Query 2, but the peak threshold is the average of each single DAY rather
-- than of the whole period.
-- Constructs: join, IN sub-query, CORRELATED sub-query with a date predicate.
-- Performance: the daily AVG is recomputed per row -> see 05.
-- -----------------------------------------------------------------------------
SELECT
    g.primary_source,
    AVG(g.actual_generation) AS avg_generation_peak_mw,
    MIN(g.actual_generation) AS min_generation_peak_mw,
    MAX(g.actual_generation) AS max_generation_peak_mw,
    COUNT(*)                 AS num_peak_observations
FROM clean.generation_data g, clean.demand_data d
WHERE g.date = d.date
  AND d.bidding_zone = 'Italy'
  AND g.primary_source IN (
        SELECT source_name
        FROM clean.source
        WHERE renewable = TRUE
  )
  AND d.total_load_mw > (
        SELECT AVG(d2.total_load_mw)
        FROM clean.demand_data d2
        WHERE d2.bidding_zone = 'Italy'
          AND DATE(d2.date) = DATE(d.date)
  )
GROUP BY g.primary_source
ORDER BY avg_generation_peak_mw DESC;


-- -----------------------------------------------------------------------------
-- QUERY 9 (*) - MSD6 margins not covered by intra-day limits
-- Zone pairs whose last balancing session carries an above-average margin that
-- no intra-day transit limit is able to cover.
-- Constructs: join, NEGATED sub-query (anti-join), HAVING with a sub-query.
-- Performance: the anti-join scans intraday_market repeatedly -> see 05.
-- -----------------------------------------------------------------------------
SELECT
    b.zone_from,
    b.zone_to,
    AVG(b.margin_mw)                      AS avg_msd_margin_mw,
    AVG(mgp.forecast_transit_limit_mw)    AS avg_mgp_limit_mw,
    MAX(b.margin_mw)                      AS peak_margin_mw,
    COUNT(*)                              AS num_observations
FROM clean.balancing_market b, clean.day_ahead_market mgp
WHERE b.zone_from = mgp.zone_from
  AND b.zone_to = mgp.zone_to
  AND b.session = 'MSD6'
  AND NOT EXISTS (
        SELECT *
        FROM clean.intraday_market i
        WHERE i.zone_from = b.zone_from
          AND i.zone_to = b.zone_to
          AND i.transit_limit_mw > b.margin_mw
  )
GROUP BY b.zone_from, b.zone_to
HAVING AVG(b.margin_mw) > (
    SELECT AVG(margin_mw)
    FROM clean.balancing_market
    WHERE session = 'MSD6'
)
ORDER BY avg_msd_margin_mw DESC, peak_margin_mw DESC;


-- -----------------------------------------------------------------------------
-- QUERY 10 (*) - Generation during critical hours
-- Critical hour = at least one zone whose absolute forecast error is more than
-- twice the average error recorded across zones in that same timestamp.
-- Constructs: EXISTS with a doubly nested, doubly correlated sub-query.
-- Performance: two levels of correlation -> see 05.
-- -----------------------------------------------------------------------------
SELECT
    g.primary_source,
    AVG(g.actual_generation) AS avg_generation_critical_mw,
    MAX(g.actual_generation) AS peak_generation_critical_mw,
    COUNT(*)                 AS num_critical_obs
FROM clean.generation_data g
WHERE EXISTS (
    SELECT *
    FROM clean.demand_data d
    WHERE d.date = g.date
      AND d.bidding_zone <> 'Italy'
      AND ABS(d.total_load_mw - d.forecast_total_load_mw) > 2 * (
            SELECT AVG(ABS(d2.total_load_mw - d2.forecast_total_load_mw))
            FROM clean.demand_data d2
            WHERE d2.date = g.date
              AND d2.bidding_zone <> 'Italy'
      )
)
GROUP BY g.primary_source
ORDER BY avg_generation_critical_mw DESC;
