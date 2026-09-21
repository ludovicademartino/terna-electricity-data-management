// =============================================================================
// QUERY 4 AS A PROPERTY GRAPH
// Data Management for Data Science - Homework 3 (Neo4j)
// =============================================================================
// Query 4 is about pairs of connected zones (source, target, margin), which is
// naturally a graph rather than a table. Zones become nodes and every balancing
// margin becomes a directed relationship between two zones, so the SQL join plus
// GROUP BY turns into a network that can be read directly - and drawn on a map
// (see viz/query04-congestion-map.html).
//
// Why not a spatial database: Oracle Spatial was considered first, but it needs
// exact coordinates for every zone. Terna's dataset does not provide them, and
// they could not be reliably attributed to the Italian bidding zones and the
// foreign borders involved. Neo4j models the same query without coordinates.
//
// Place the two CSV exports in the Neo4j `import` directory before running.
// =============================================================================


// -----------------------------------------------------------------------------
// 1. Load the raw MSD records - one relationship per margin observation
// -----------------------------------------------------------------------------
LOAD CSV WITH HEADERS FROM 'file:///MERCATO%20MSD%28Export%29.csv' AS row
MERGE (a:Zone {name: row['Zone From']})
MERGE (b:Zone {name: row['Zone To']})
CREATE (a)-[:MSD_RAW {
    date:    row['Date'],
    session: row['Session'],
    margin:  toFloat(row['Margin (MW)'])
}]->(b);


// -----------------------------------------------------------------------------
// 2. Load the MSD input records - forecast load per (date, session)
// -----------------------------------------------------------------------------
LOAD CSV WITH HEADERS FROM 'file:///MERCATO_MSD_INPUT%28Export%29.csv' AS row
CREATE (:Input {
    date:          row['Date'],
    session:       row['Session'],
    forecast_load: toFloat(row['Forecast Load [MW]'])
});


// -----------------------------------------------------------------------------
// 3. Aggregate into MSD_LINK edges, already flagging the congested ones
//    (congested = average margin below the global average, i.e. the HAVING
//    clause of the SQL version)
// -----------------------------------------------------------------------------
MATCH ()-[r:MSD_RAW]->()
WITH avg(r.margin) AS soglia_q4
MATCH (a:Zone)-[msd:MSD_RAW]->(b:Zone), (inp:Input)
WHERE inp.date = msd.date AND inp.session = msd.session
WITH a, b, msd.session AS session, soglia_q4,
     avg(msd.margin)        AS avg_margin_mw,
     avg(inp.forecast_load) AS avg_forecast_load_mw
CREATE (a)-[:MSD_LINK {
    session:       session,
    margin:        avg_margin_mw,
    forecast_load: avg_forecast_load_mw,
    congested:     avg_margin_mw < soglia_q4
}]->(b);


// -----------------------------------------------------------------------------
// 4. Read the result
// -----------------------------------------------------------------------------

// the whole network
MATCH (n)-[r:MSD_LINK]->(m) RETURN n, r, m;

// only the congested links - the 162 rows returned by Query 4 in SQL and Mongo
MATCH (n)-[r:MSD_LINK {congested: true}]->(m) RETURN n, r, m;
