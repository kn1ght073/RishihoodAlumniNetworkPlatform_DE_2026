# Query Optimization Report

**Project:** Housing.com Property Search Database · **Team T0079** · **Phase 4 (CP3)**

## What changed

Added workload-focused PostgreSQL indexes in [`sql/05_indexes.sql`](../sql/05_indexes.sql). They cover common property filters and ordering, locality lookups, owner and project joins, enquiry/visit existence checks, shortlist conversion, and the nightly stale-listing update. Partial indexes keep several indexes limited to the rows queried by the workload. The primary-key and unique indexes already created by the schema remain in place.

In [`sql/06_optimized_queries.sql`](../sql/06_optimized_queries.sql), R19 now aggregates enquiries once by property and left-joins the result to active Bengaluru sale listings. This removes two correlated enquiry lookups per property. The left join retains listings without enquiries, and `coalesce` preserves the original count of zero. All other R01–R25 and W01–W05 statements retain their supplied workload form and markers.

## Indexes and workload coverage

| Workload area | Supporting indexes |
|---|---|
| R01–R05 searches, trends and map | Locality name/city; active rent and sale filters; map coordinates; locality and listing type |
| R06–R08 dashboards, schedules and alerts | Lister, visit schedule and price-change date indexes |
| R09–R13 amenities, project listings and anti-join | Amenity name, reverse project-amenity lookup, project/status, enquiry and visit keys |
| R14–R22 reports, stale listings, duplicates and moderation | Deal date, active posted date, locality/type, duplicate grouping, and descending posted date |
| R25 and writes | Reverse shortlist key plus lister and active-posted indexes |

R03, R10, R16, R23 and R24 already benefit from primary/unique indexes or small reference tables, so the design avoids adding specialized indexes solely for those lookups. The broad aggregation in R18 and the date cast in R20 may still need sequential work; the workload is left unchanged to preserve its specified result semantics.

## Benchmark status

The supplied baseline reports an average total of **10,098.879 ms**. R19 is the largest baseline cost at **9,495.191 ms**, followed by R25 at **306.878 ms**. No optimized timings are claimed yet: the current environment does not have the PostgreSQL `psql` client or a reachable benchmark database. Accordingly, [`benchmarks/results/optimized/summary.csv`](../benchmarks/results/optimized/summary.csv) lists every workload query with timing fields blank until a real run is made.

After loading the seed data into PostgreSQL, run from this project directory:

```sh
psql -d housing -f sql/05_indexes.sql
./benchmarks/run_benchmark.sh housing optimized 3 sql/06_optimized_queries.sql
```

The benchmark runner writes the measured summary and raw plans into `benchmarks/results/optimized/`. Compare query results before interpreting timing changes; the provided runner captures plans and elapsed time but does not compare result sets.

## Notes

- Indexes add storage and make inserts and updates somewhat more expensive. The workload-specific partial indexes limit some of that cost, but the trade-off should be reviewed against real write volume.
- `ANALYZE` is run at the end of the index script so PostgreSQL can plan with refreshed statistics.
- R13 is intentionally unchanged. Because the supplied `NOT IN` subquery can contain `NULL` project IDs, replacing it with `NOT EXISTS` could change its result.
