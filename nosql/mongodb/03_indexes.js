// =============================================================================
// 03 - INDEXES
// Data Management for Data Science - Homework 3 (MongoDB)
// =============================================================================
// Homework 3 does not require an optimisation comparison, but two indexes are
// needed to keep the heavier pipelines usable on the full dataset. They are
// repeated inline in 04_queries.js, next to the query that needs them.
//
// Run in mongosh:  mongosh terna nosql/mongodb/03_indexes.js
// =============================================================================

// Query 4: keeps the $lookup fast against the large balancing_market collection
db.input_avg_by_ds.createIndex({ date: 1, session: 1 });

// Query 9: speeds up the anti-join probe on intraday_market
db.intraday_market.createIndex({ zone_from: 1, zone_to: 1, transit_limit_mw: 1 });
