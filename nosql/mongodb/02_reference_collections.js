// =============================================================================
// 02 - REFERENCE COLLECTIONS
// Data Management for Data Science - Homework 3 (MongoDB)
// =============================================================================
// The document model has no foreign keys, but the two dimension tables of
// Homework 1 are still useful: they are recreated here as plain collections and
// joined with $lookup only when a query actually needs them.
//
// Run in mongosh:  mongosh terna nosql/mongodb/02_reference_collections.js
// =============================================================================

// --- ZONE ---------------------------------------------------------------------
db.zone.drop();
db.zone.insertMany([
  // Italian bidding zones
  { zone_name: "Calabria",      is_italian: true,  is_aggregate: false },
  { zone_name: "Centre-North",  is_italian: true,  is_aggregate: false },
  { zone_name: "Centre-South",  is_italian: true,  is_aggregate: false },
  { zone_name: "North",         is_italian: true,  is_aggregate: false },
  { zone_name: "Sardinia",      is_italian: true,  is_aggregate: false },
  { zone_name: "Sicily",        is_italian: true,  is_aggregate: false },
  { zone_name: "South",         is_italian: true,  is_aggregate: false },
  // national aggregate
  { zone_name: "Italy",         is_italian: true,  is_aggregate: true  },
  // foreign borders and virtual nodes
  { zone_name: "Austria",       is_italian: false, is_aggregate: false },
  { zone_name: "Austria 2",     is_italian: false, is_aggregate: false },
  { zone_name: "France",        is_italian: false, is_aggregate: false },
  { zone_name: "France 2",      is_italian: false, is_aggregate: false },
  { zone_name: "Switzerland",   is_italian: false, is_aggregate: false },
  { zone_name: "Switzerland 2", is_italian: false, is_aggregate: false },
  { zone_name: "Slovenia",      is_italian: false, is_aggregate: false },
  { zone_name: "Greece",        is_italian: false, is_aggregate: false },
  { zone_name: "Greece 2",      is_italian: false, is_aggregate: false },
  { zone_name: "Malta",         is_italian: false, is_aggregate: false },
  { zone_name: "Montenegro",    is_italian: false, is_aggregate: false },
  { zone_name: "Corsica",       is_italian: false, is_aggregate: false },
  { zone_name: "Corsica AC",    is_italian: false, is_aggregate: false },
  { zone_name: "BSP",           is_italian: false, is_aggregate: false },
  { zone_name: "Coupling",      is_italian: false, is_aggregate: false }
]);

// --- SOURCE -------------------------------------------------------------------
db.source.drop();
db.source.insertMany([
  { source_name: "Geothermal",       renewable: true  },
  { source_name: "Hydro",            renewable: true  },
  { source_name: "Photovoltaic",     renewable: true  },
  { source_name: "Wind",             renewable: true  },
  { source_name: "Self-consumption", renewable: false },
  { source_name: "Thermal",          renewable: false }
]);
