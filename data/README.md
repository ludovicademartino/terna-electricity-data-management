# Data

The CSV exports are **not** tracked in this repository: they are public data that
can be re-downloaded, and together they are large enough to be an awkward fit for
git. This folder is where the loading scripts expect them.

## Where the data comes from

All files come from the **Terna Download Center**, the open-data portal of the
Italian transmission system operator:

<https://www.terna.it/en/electric-system/transparency-report/download-center>

The dataset used for the homeworks covers **January, February and March 2026**.

## Files to download

| Terna section (IT)     | File as exported                       | Loads into                   | Rows    |
| ---------------------- | -------------------------------------- | ---------------------------- | ------: |
| Fabbisogno             | `FABBISOGNO_DATI(Export).csv`          | `raw.demand_data`            |  19,200 |
| Generazione            | `GENERAZIONE_DATI(Export).csv`         | `raw.generation_data`        |  14,400 |
| Trasmissione           | `TRASMISSIONE_DATI(Export).csv`        | `raw.transmission_data`      |  19,200 |
| Mercato MGP            | `MERCATO_GIORNO_PRIMA(Export).csv`     | `raw.day_ahead_market`       |  29,568 |
| Mercato MI             | `MERCATO_INFRAGIORNALIERO(Export).csv` | `raw.intraday_market`        |  67,056 |
| Mercato MSD            | `MERCATO MSD(Export).csv`              | `raw.balancing_market`       | 375,232 |
| Mercato MSD input      | `MERCATO_MSD_INPUT(Export).csv`        | `raw.balancing_market_input` |  61,040 |
| Adeguatezza consuntivo | `ADEGUATEZZA_CONSUNTIVO(Export).csv`   | `raw.adequacy_actual`        |   6,048 |
| Adeguatezza previsione | `ADEGUATEZZA_PREVISIONE(Export).csv`   | `raw.adequacy_forecast`      |  22,290 |
| Connessioni FER        | `CONNESSIONI(Export).csv`              | `raw.connections`            |      65 |

Row counts are data rows, i.e. what lands in `clean` — each file also carries a
header and the `Applied filters` footer, so it is two lines longer on disk.
Keep the names exactly as the Download Center exports them: the Neo4j
`LOAD CSV` statements reference the two MSD files verbatim (URL-encoded).

## A quirk worth knowing

Every export ends with a footer row starting with `Applied filters ...`.
It is deliberately kept in the `raw` layer and filtered out on the way into
`clean`, by the `WHERE ... NOT LIKE 'Applied filters%'` predicate in
[`sql/02_clean_schema.sql`](../sql/02_clean_schema.sql).

## Loading

**PostgreSQL** — from `psql`, after running `sql/01_raw_schema.sql`:

```sql
\copy raw.demand_data FROM 'data/FABBISOGNO_DATI(Export).csv' WITH (FORMAT csv, HEADER true);
```

**MongoDB** — import each CSV as its own collection, either with
Compass (*Add Data → Import file*) or with `mongoimport`:

```bash
mongoimport --db terna --collection demand --type csv --headerline --file 'data/FABBISOGNO_DATI(Export).csv'
```

Collection names must match those used in
[`nosql/mongodb/01_transform_collections.js`](../nosql/mongodb/01_transform_collections.js).

> Note: a field name containing a dot is rejected by MongoDB, so headers such as
> `Combustibile Prev.` have to be renamed at import time.
