// =============================================================================
// 04 - THE TEN QUERIES, REFORMULATED AS AGGREGATION PIPELINES
// Data Management for Data Science - Homework 3 (MongoDB)
// =============================================================================
// All ten SQL queries of Homework 1 are reproduced here with the same meaning
// and verified to return the same results.
//
// Two recurring differences with respect to SQL:
//
//   * scalar sub-queries (the global average used in a HAVING) have no direct
//     equivalent in the aggregation framework, so they are computed first into
//     a JavaScript variable and then injected into the pipeline;
//   * derived tables become small precomputed collections written with $out,
//     which are then joined back with $lookup.
//
// Run in mongosh:  mongosh terna nosql/mongodb/04_queries.js
// =============================================================================


// -----------------------------------------------------------------------------
// QUERY 1 - Daily forecast error per zone
// SQL: HAVING avg_error > (global avg) -> var + $match after $group
// -----------------------------------------------------------------------------
var globalErr = db.demand.aggregate([
  { $match: { bidding_zone: { $ne: "Italy" } } },
  { $group: { _id: null, g: { $avg: { $abs: { $subtract: ["$total_load_mw", "$forecast_total_load_mw"] } } } } }
]).toArray()[0].g;

db.demand.aggregate([
  { $match: { bidding_zone: { $ne: "Italy" } } },
  { $group: {
      _id: { date: "$date", zone: "$bidding_zone" },
      avg_forecast_mw: { $avg: "$forecast_total_load_mw" },
      avg_load_mw: { $avg: "$total_load_mw" },
      absolute_avg_error_mw: { $avg: { $abs: { $subtract: ["$total_load_mw", "$forecast_total_load_mw"] } } }
  }},
  { $match: { absolute_avg_error_mw: { $gt: globalErr } } },
  { $sort: { absolute_avg_error_mw: -1, "_id.date": 1 } },
  { $project: { _id: 0,
      date: { $dateToString: { format: "%Y-%m-%d", date: "$_id.date" } },
      bidding_zone: "$_id.zone",
      avg_forecast_mw: 1, avg_load_mw: 1, absolute_avg_error_mw: 1 } }
]);


// -----------------------------------------------------------------------------
// QUERY 2 - Renewables during high-load hours
// SQL: IN sub-query -> array of source names; peak hours materialised with $out
// -----------------------------------------------------------------------------
var avgItaly = db.demand.aggregate([
  { $match: { bidding_zone: "Italy" } },
  { $group: { _id: null, a: { $avg: "$total_load_mw" } } }
]).toArray()[0].a;

var renew = db.source.find({ renewable: true }).toArray().map(s => s.source_name);

db.demand.aggregate([
  { $match: { bidding_zone: "Italy", total_load_mw: { $gt: avgItaly } } },
  { $project: { _id: 0, date: 1 } },
  { $out: "italy_peak_dates" }
]);

db.generation.aggregate([
  { $match: { primary_source: { $in: renew } } },
  { $lookup: { from: "italy_peak_dates", localField: "date", foreignField: "date", as: "pk" } },
  { $unwind: "$pk" },
  { $group: {
      _id: "$primary_source",
      avg_generation_mw: { $avg: "$actual_generation" },
      min_generation_mw: { $min: "$actual_generation" },
      max_generation_mw: { $max: "$actual_generation" },
      total_generation_mw: { $sum: "$actual_generation" }
  }},
  { $sort: { total_generation_mw: -1 } },
  { $project: { _id: 0, primary_source: "$_id", avg_generation_mw: 1, min_generation_mw: 1,
      max_generation_mw: 1, total_generation_mw: 1 } }
]);


// -----------------------------------------------------------------------------
// QUERY 3 - Countries with a net import balance
// SQL: correlated sub-query -> precomputed per-country average + $lookup
// -----------------------------------------------------------------------------
db.transmission.aggregate([
  { $group: { _id: "$country", avg_import_country: { $avg: "$import_mw" } } },
  { $out: "country_avg_import" }
]);

db.transmission.aggregate([
  { $lookup: { from: "country_avg_import", localField: "country", foreignField: "_id", as: "ca" } },
  { $unwind: "$ca" },
  { $match: { import_mw: { $gt: 0 }, $expr: { $gt: ["$import_mw", "$ca.avg_import_country"] } } },
  { $group: {
      _id: "$country",
      avg_import_mw: { $avg: "$import_mw" },
      avg_balance_mw: { $avg: "$scheduled_foreign_exchange" },
      peak_import_mw: { $max: "$import_mw" },
      num_high_import_hours: { $sum: 1 }
  }},
  { $match: { avg_balance_mw: { $gt: 0 } } },
  { $sort: { avg_balance_mw: -1, peak_import_mw: -1 } },
  { $project: { _id: 0, country: "$_id", avg_import_mw: 1, avg_balance_mw: 1,
      peak_import_mw: 1, num_high_import_hours: 1 } }
]);


// -----------------------------------------------------------------------------
// QUERY 4 - MSD margins against forecast load
// SQL: join on (date, session) -> $lookup with a `let` pipeline on both keys
// This is the query rebuilt as a graph in Neo4j and drawn on the map.
// -----------------------------------------------------------------------------
db.balancing_market_input.aggregate([
  { $group: { _id: { date: "$date", session: "$session" }, avg_load: { $avg: "$forecast_load_mw" } } },
  { $project: { _id: 0, date: "$_id.date", session: "$_id.session", avg_load: 1 } },
  { $out: "input_avg_by_ds" }
]);

db.input_avg_by_ds.createIndex({ date: 1, session: 1 });

var globalAvgMargin = db.balancing_market.aggregate([
  { $group: { _id: null, a: { $avg: "$margin_mw" } } }
]).toArray()[0].a;

db.balancing_market.aggregate([
  { $lookup: {
      from: "input_avg_by_ds",
      let: { d: "$date", s: "$session" },
      pipeline: [ { $match: { $expr: { $and: [ { $eq: ["$date", "$$d"] }, { $eq: ["$session", "$$s"] } ] } } } ],
      as: "inp"
  }},
  { $unwind: "$inp" },
  { $group: {
      _id: { zone_from: "$zone_from", zone_to: "$zone_to", session: "$session" },
      avg_margin_mw: { $avg: "$margin_mw" },
      forecast_avg_load_mw: { $avg: "$inp.avg_load" }
  }},
  { $match: { avg_margin_mw: { $lt: globalAvgMargin } } },
  { $sort: { avg_margin_mw: 1, forecast_avg_load_mw: -1 } },
  { $project: { _id: 0, zone_from: "$_id.zone_from", zone_to: "$_id.zone_to",
      session: "$_id.session", avg_margin_mw: 1, forecast_avg_load_mw: 1 } }
], { allowDiskUse: true });


// -----------------------------------------------------------------------------
// QUERY 5 - Below-average available capacity per macroarea
// SQL: derived table joined back -> $out + $lookup on the macroarea
// -----------------------------------------------------------------------------
db.adequacy_actual.aggregate([
  { $group: { _id: "$macroarea", avg_capacity_macroarea: { $avg: "$available_capacity_mw" } } },
  { $out: "macroarea_avg" }
]);

db.adequacy_actual.aggregate([
  { $group: {
      _id: { macroarea: "$macroarea", plant_type: "$plant_type", fuel: "$fuel" },
      avg_available_capacity_mw: { $avg: "$available_capacity_mw" }
  }},
  { $lookup: { from: "macroarea_avg", localField: "_id.macroarea", foreignField: "_id", as: "ma" } },
  { $unwind: "$ma" },
  { $match: { $expr: { $lt: ["$avg_available_capacity_mw", "$ma.avg_capacity_macroarea"] } } },
  { $sort: { "_id.macroarea": 1, avg_available_capacity_mw: 1 } },
  { $project: { _id: 0, macroarea: "$_id.macroarea", plant_type: "$_id.plant_type", fuel: "$_id.fuel",
      avg_available_capacity_mw: 1, avg_capacity_macroarea: "$ma.avg_capacity_macroarea" } }
]);


// -----------------------------------------------------------------------------
// QUERY 6 - North vs South-and-Islands comparison
// SQL: UNION of two aggregates -> there is no UNION stage between two $groups on
// the same collection, so the two halves are run as two separate pipelines.
// -----------------------------------------------------------------------------
db.demand.aggregate([
  { $match: { bidding_zone: { $in: ["North", "Centre-North"] } } },
  { $group: { _id: "North",
      avg_load_mw: { $avg: "$total_load_mw" },
      min_load_mw: { $min: "$total_load_mw" },
      max_load_mw: { $max: "$total_load_mw" },
      avg_forecast_mw: { $avg: "$forecast_total_load_mw" },
      avg_forecast_error_mw: { $avg: { $abs: { $subtract: ["$total_load_mw", "$forecast_total_load_mw"] } } } } },
  { $project: { _id: 0, macro_area: "$_id", avg_load_mw: 1, min_load_mw: 1, max_load_mw: 1,
      load_range_mw: { $subtract: ["$max_load_mw", "$min_load_mw"] },
      avg_forecast_mw: 1, avg_forecast_error_mw: 1 } }
]);

db.demand.aggregate([
  { $match: { bidding_zone: { $in: ["Centre-South", "South", "Calabria", "Sicily", "Sardinia"] } } },
  { $group: { _id: "South and Islands",
      avg_load_mw: { $avg: "$total_load_mw" },
      min_load_mw: { $min: "$total_load_mw" },
      max_load_mw: { $max: "$total_load_mw" },
      avg_forecast_mw: { $avg: "$forecast_total_load_mw" },
      avg_forecast_error_mw: { $avg: { $abs: { $subtract: ["$total_load_mw", "$forecast_total_load_mw"] } } } } },
  { $project: { _id: 0, macro_area: "$_id", avg_load_mw: 1, min_load_mw: 1, max_load_mw: 1,
      load_range_mw: { $subtract: ["$max_load_mw", "$min_load_mw"] },
      avg_forecast_mw: 1, avg_forecast_error_mw: 1 } }
]);


// -----------------------------------------------------------------------------
// QUERY 7 - Connection requests never reaching a final contract
// SQL: NOT EXISTS -> self-$lookup with a `let` pipeline, then $match size 0
// -----------------------------------------------------------------------------
db.connections.aggregate([
  { $match: { connection_status: { $ne: "STMD/Contratti" } } },
  { $lookup: {
      from: "connections",
      let: { r: "$region", s: "$source" },
      pipeline: [ { $match: { $expr: { $and: [
            { $eq: ["$region", "$$r"] },
            { $eq: ["$source", "$$s"] },
            { $eq: ["$connection_status", "STMD/Contratti"] }
      ] } } } ],
      as: "contracts"
  }},
  { $match: { contracts: { $size: 0 } } },   // this is the anti-join
  { $group: {
      _id: { region: "$region", source: "$source" },
      total_capacity_requested_mw: { $sum: "$capacity_mw" },
      total_number_requests: { $sum: "$num_requests" }
  }},
  { $sort: { total_capacity_requested_mw: -1 } },
  { $project: { _id: 0, region: "$_id.region", source: "$_id.source",
      total_capacity_requested_mw: 1, total_number_requests: 1 } }
]);


// -----------------------------------------------------------------------------
// QUERY 8 - Renewable generation on daily peak hours
// SQL: correlated daily AVG -> daily averages materialised, then peak dates
// -----------------------------------------------------------------------------
db.demand.aggregate([
  { $match: { bidding_zone: "Italy" } },
  { $group: { _id: { $dateToString: { format: "%Y-%m-%d", date: "$date" } }, day_avg: { $avg: "$total_load_mw" } } },
  { $out: "italy_daily_avg" }
]);

db.demand.aggregate([
  { $match: { bidding_zone: "Italy" } },
  { $addFields: { day: { $dateToString: { format: "%Y-%m-%d", date: "$date" } } } },
  { $lookup: { from: "italy_daily_avg", localField: "day", foreignField: "_id", as: "da" } },
  { $unwind: "$da" },
  { $match: { $expr: { $gt: ["$total_load_mw", "$da.day_avg"] } } },
  { $project: { _id: 0, date: 1 } },
  { $out: "italy_peak_dates_daily" }
]);

var renew2 = db.source.find({ renewable: true }).toArray().map(s => s.source_name);

db.generation.aggregate([
  { $match: { primary_source: { $in: renew2 } } },
  { $lookup: { from: "italy_peak_dates_daily", localField: "date", foreignField: "date", as: "pk" } },
  { $unwind: "$pk" },
  { $group: {
      _id: "$primary_source",
      avg_generation_peak_mw: { $avg: "$actual_generation" },
      min_generation_peak_mw: { $min: "$actual_generation" },
      max_generation_peak_mw: { $max: "$actual_generation" },
      num_peak_observations: { $sum: 1 }
  }},
  { $sort: { avg_generation_peak_mw: -1 } },
  { $project: { _id: 0, primary_source: "$_id", avg_generation_peak_mw: 1,
      min_generation_peak_mw: 1, max_generation_peak_mw: 1, num_peak_observations: 1 } }
]);


// -----------------------------------------------------------------------------
// QUERY 9 - MSD6 margins not covered by intra-day limits
// SQL: NOT EXISTS + join on MGP -> anti-join $lookup ($limit 1 is enough) plus a
// per-pair MGP average precomputed beforehand, so the join does not explode.
// -----------------------------------------------------------------------------
db.day_ahead_market.aggregate([
  { $group: { _id: { zf: "$zone_from", zt: "$zone_to" }, avg_mgp_limit: { $avg: "$forecast_transit_limit_mw" } } },
  { $out: "mgp_avg_by_pair" }
]);

db.intraday_market.createIndex({ zone_from: 1, zone_to: 1, transit_limit_mw: 1 });

var avgMSD6 = db.balancing_market.aggregate([
  { $match: { session: "MSD6" } },
  { $group: { _id: null, a: { $avg: "$margin_mw" } } }
]).toArray()[0].a;

db.balancing_market.aggregate([
  { $match: { session: "MSD6" } },
  { $lookup: {
      from: "intraday_market",
      let: { zf: "$zone_from", zt: "$zone_to", m: "$margin_mw" },
      pipeline: [
        { $match: { $expr: { $and: [
            { $eq: ["$zone_from", "$$zf"] },
            { $eq: ["$zone_to", "$$zt"] },
            { $gt: ["$transit_limit_mw", "$$m"] }
        ] } } },
        { $limit: 1 }
      ],
      as: "covered"
  }},
  { $match: { covered: { $size: 0 } } },
  // average MGP limit per pair: one row per pair, so the join does not explode
  { $lookup: {
      from: "mgp_avg_by_pair",
      let: { zf: "$zone_from", zt: "$zone_to" },
      pipeline: [ { $match: { $expr: { $and: [ { $eq: ["$_id.zf", "$$zf"] }, { $eq: ["$_id.zt", "$$zt"] } ] } } } ],
      as: "mgp"
  }},
  { $unwind: "$mgp" },
  { $group: {
      _id: { zone_from: "$zone_from", zone_to: "$zone_to" },
      avg_msd_margin_mw: { $avg: "$margin_mw" },
      avg_mgp_limit_mw: { $avg: "$mgp.avg_mgp_limit" },
      peak_margin_mw: { $max: "$margin_mw" },
      num_observations: { $sum: 1 }
  }},
  { $match: { avg_msd_margin_mw: { $gt: avgMSD6 } } },
  { $sort: { avg_msd_margin_mw: -1, peak_margin_mw: -1 } },
  { $project: { _id: 0, zone_from: "$_id.zone_from", zone_to: "$_id.zone_to",
      avg_msd_margin_mw: 1, avg_mgp_limit_mw: 1, peak_margin_mw: 1, num_observations: 1 } }
], { allowDiskUse: true });


// -----------------------------------------------------------------------------
// QUERY 10 - Generation during critical hours
// SQL: doubly nested correlated sub-query -> the same decomposition used in the
// Homework 2 optimisation: per-timestamp average error, then critical hours.
// -----------------------------------------------------------------------------
db.demand.aggregate([
  { $match: { bidding_zone: { $ne: "Italy" } } },
  { $group: { _id: "$date", avg_err: { $avg: { $abs: { $subtract: ["$total_load_mw", "$forecast_total_load_mw"] } } } } },
  { $out: "ts_avg_err" }
]);

db.demand.aggregate([
  { $match: { bidding_zone: { $ne: "Italy" } } },
  { $lookup: { from: "ts_avg_err", localField: "date", foreignField: "_id", as: "e" } },
  { $unwind: "$e" },
  { $match: { $expr: { $gt: [
      { $abs: { $subtract: ["$total_load_mw", "$forecast_total_load_mw"] } },
      { $multiply: [2, "$e.avg_err"] }
  ] } } },
  { $group: { _id: "$date" } },
  { $out: "critical_hours" }
]);

db.generation.aggregate([
  { $lookup: { from: "critical_hours", localField: "date", foreignField: "_id", as: "c" } },
  { $unwind: "$c" },
  { $group: {
      _id: "$primary_source",
      avg_generation_critical_mw: { $avg: "$actual_generation" },
      peak_generation_critical_mw: { $max: "$actual_generation" },
      num_critical_obs: { $sum: 1 }
  }},
  { $sort: { avg_generation_critical_mw: -1 } },
  { $project: { _id: 0, primary_source: "$_id", avg_generation_critical_mw: 1,
      peak_generation_critical_mw: 1, num_critical_obs: 1 } }
]);
