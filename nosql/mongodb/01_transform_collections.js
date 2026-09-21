// =============================================================================
// 01 - IMPORT AND FIELD TRANSFORMATION
// Data Management for Data Science - Homework 3 (MongoDB)
// =============================================================================
// Each Terna CSV is imported as its own collection into the `terna` database
// (MongoDB Compass -> Add Data -> Import file, or `mongoimport`).
//
// Import leaves the original Italian/bracketed CSV headers and stores every
// value as a string. This script realigns the documents with the relational
// `clean` schema of Homework 1:
//   * parses `Date` into a native BSON Date
//   * casts the measures to double
//   * renames every field to its snake_case name, then unsets the originals
//
// Note: a dot is not allowed in a MongoDB field name, so headers such as
// "Combustibile Prev." were renamed at import time.
//
// Run in mongosh:  mongosh terna nosql/mongodb/01_transform_collections.js
// =============================================================================

const D = { dateString: "$Date", format: "%d/%m/%Y %H:%M:%S" };

// --- FABBISOGNO / demand ------------------------------------------------------
db.demand.updateMany({}, [
  { $set: {
      date: { $dateFromString: D },
      total_load_mw: { $toDouble: "$Total Load [MW]" },
      forecast_total_load_mw: { $toDouble: "$Forecast Total Load [MW]" },
      bidding_zone: "$Bidding Zone"
  }},
  { $unset: ["Date", "Total Load [MW]", "Forecast Total Load [MW]", "Bidding Zone"] }
]);

// --- TRASMISSIONE / cross-border exchange -------------------------------------
db.transmission.updateMany({}, [
  { $set: {
      date: { $dateFromString: D },
      country: "$Country",
      import_mw: { $toDouble: "$Import" },
      export_mw: { $toDouble: "$Export" },
      scheduled_foreign_exchange: { $toDouble: "$Scheduled Foreign Exchange" }
  }},
  { $unset: ["Date", "Country", "Import", "Export", "Scheduled Foreign Exchange"] }
]);

// --- GENERAZIONE / generation by primary source -------------------------------
db.generation.updateMany({}, [
  { $set: {
      date: { $dateFromString: D },
      actual_generation: { $toDouble: "$Actual Generation" },
      primary_source: "$Primary Source"
  }},
  { $unset: ["Date", "Actual Generation", "Primary Source"] }
]);

// --- MI / intra-day market ----------------------------------------------------
db.intraday_market.updateMany({}, [
  { $set: {
      date: { $dateFromString: D },
      session: "$Session",
      zone_from: "$Zone From",
      zone_to: "$Zone To",
      transit_limit_mw: { $toDouble: "$Transit Limit [MW]" }
  }},
  { $unset: ["Date", "Session", "Zone From", "Zone To", "Transit Limit [MW]"] }
]);

// --- MSD / balancing market ---------------------------------------------------
db.balancing_market.updateMany({}, [
  { $set: {
      date: { $dateFromString: D },
      session: "$Session",
      zone_from: "$Zone From",
      zone_to: "$Zone To",
      margin_mw: { $toDouble: "$Margin (MW)" }
  }},
  { $unset: ["Date", "Session", "Zone From", "Zone To", "Margin (MW)"] }
]);

// --- MSD INPUT / forecast load per session ------------------------------------
db.balancing_market_input.updateMany({}, [
  { $set: {
      date: { $dateFromString: D },
      session: "$Session",
      zone: "$Zone",
      forecast_load_mw: { $toDouble: "$Forecast Load [MW]" }
  }},
  { $unset: ["Date", "Session", "Zone", "Forecast Load [MW]"] }
]);

// --- MGP / day-ahead market ---------------------------------------------------
db.day_ahead_market.updateMany({}, [
  { $set: {
      date: { $dateFromString: D },
      zone_from: "$Zone From",
      zone_to: "$Zone To",
      forecast_transit_limit_mw: { $toDouble: "$Forecast Transit Limit [MW]" }
  }},
  { $unset: ["Date", "Zone From", "Zone To", "Forecast Transit Limit [MW]"] }
]);

// --- ADEGUATEZZA CONSUNTIVO / actual available capacity -----------------------
db.adequacy_actual.updateMany({}, [
  { $set: {
      date: { $dateFromString: D },
      macroarea: "$Macroarea",
      plant_type: "$Tipo Impianto",
      fuel: "$Combustibile Prev",
      available_capacity_mw: { $toDouble: "$Available Capacity [MW]" }
  }},
  { $unset: ["Date", "Macroarea", "Tipo Impianto", "Combustibile Prev", "Available Capacity [MW]"] }
]);

// --- CONNESSIONI / grid-connection requests -----------------------------------
db.connections.updateMany({}, [
  { $set: {
      region: "$Regione",
      plant_type: "$Tipo Impianto",
      source: "$Fonte",
      connection_status: "$Stato Connessione",
      capacity_mw: { $toDouble: "$Potenza (MW)" },
      num_requests: { $toDouble: "$Numero Pratiche" }
  }},
  { $unset: ["Regione", "Tipo Impianto", "Fonte", "Stato Connessione", "Potenza (MW)", "Numero Pratiche"] }
]);

// Note: `adequacy_forecast` is imported as a collection as well, but none of the
// ten queries reads it, so it is left with its original CSV field names.
