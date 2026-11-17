# Baseline Query Timings

**Project:** Housing.com Property Search Database · **Team T0079** · **Phase 3 (CP2)**

All 30 workload queries from [`queries/workload_30.sql`](../queries/workload_30.sql) were benchmarked against the unindexed baseline schema loaded in Phase 2 ([`sql/01_schema.sql`](../sql/01_schema.sql)).

In this baseline state, the database has **only primary key and unique constraints** (auto-indexed by PostgreSQL B-trees). No secondary indexes, composite indexes, foreign key indexes, or expression indexes exist. All write queries (`W01`–`W05`) were benchmarked inside `BEGIN ... ROLLBACK` blocks to maintain identical database state across iterations.

---

## 1. Benchmarking Environment & Methodology

- **Database Engine:** PostgreSQL 14 (macOS / Apple Silicon)
- **Schema:** `housing`
- **Database Name:** `housing`
- **Data Volume:** Full seed dataset (120,060 properties, 100,000 enquiries, 69,999 shortlists, 35,120 site visits, 23,425 price changes, 6,806 project amenities, 1,200 projects, 150 builders, 100 localities, 10 cities, 15 amenities, 40,000 users).
- **Execution Tool:** [`benchmarks/run_benchmark.sh`](../benchmarks/run_benchmark.sh)
- **Measurement Method:** Each query is executed with `EXPLAIN (ANALYZE, BUFFERS)` for 3 consecutive runs (`Run 1`, `Run 2`, `Run 3`). The execution times are captured from the `Execution Time` metric reported by libpq, and the arithmetic average across the 3 runs is computed.
- **Summary Output:** [`benchmarks/results/baseline/summary.csv`](../benchmarks/results/baseline/summary.csv)
- **Raw Query Plans:** [`benchmarks/results/baseline/`](../benchmarks/results/baseline/) (`R01.txt` through `R25.txt`, `W01.txt` through `W05.txt`)

---

## 2. Baseline Timing Table (All 30 Workload Queries)

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Rent search: active 2 BHK homes in Koramangala up to ₹40,000/month, furnished or semi-furnished | READ | 10.145 | 8.822 | 8.164 | 9.044 |
| R02: Buy search: 3 BHK apartments for sale in Pune under ₹1.2 crore, best price per sq ft first | READ | 7.873 | 7.712 | 7.533 | 7.706 |
| R03: Property page: property 6897 with its project, builder and project amenities | READ | 0.074 | 0.075 | 0.068 | 0.072 |
| R04: Price trends: average sale price per sq ft of apartments in Whitefield, per month in 2026 | READ | 14.046 | 14.238 | 13.567 | 13.950 |
| R05: Map view: active rentals inside the visible map area of central Bengaluru | READ | 4.892 | 4.651 | 4.732 | 4.758 |
| R06: Owner dashboard: owner 1033's listings with enquiry and site-visit counts | READ | 11.130 | 11.756 | 11.419 | 11.435 |
| R07: Agent app: site visits scheduled on 1 July 2026 for properties listed by user 4723 | READ | 2.571 | 2.589 | 2.610 | 2.590 |
| R08: Price-drop alerts: active properties whose price fell by 10% or more in June 2026 | READ | 1.473 | 1.480 | 1.486 | 1.480 |
| R09: Amenity filter: active properties in projects that have a gym AND a swimming pool AND power backup | READ | 12.629 | 11.893 | 11.961 | 12.161 |
| R10: Buyer due diligence: look up a project by its RERA registration id | READ | 0.042 | 0.041 | 0.038 | 0.040 |
| R11: Project page: available listings in project 217 by BHK with the price range | READ | 9.484 | 9.690 | 9.355 | 9.510 |
| R12: Lead follow-up: June 2026 enquiries with no site visit booked for that property by that user | READ | 7.888 | 8.131 | 8.260 | 8.093 |
| R13: Builder partnerships: projects with no property listed on Housing.com | READ | 11.329 | 11.338 | 11.048 | 11.238 |
| R14: Agent leaderboard: agents with the most properties sold or rented in 2026 | READ | 15.951 | 15.832 | 16.043 | 15.942 |
| R15: Investor insights: rental yield by Bengaluru locality (yearly rent per sq ft ÷ sale price per sq ft) | READ | 12.690 | 12.930 | 12.793 | 12.804 |
| R16: Search box: projects with "greens" in the name | READ | 0.334 | 0.450 | 0.359 | 0.381 |
| R17: Owner nudges: active listings older than 90 days that have never received an enquiry | READ | 27.095 | 26.851 | 27.012 | 26.986 |
| R18: Fraud checks: the same flat (locality, area, floor, BHK) listed more than once by the same lister | READ | 20.797 | 21.176 | 21.031 | 21.001 |
| R19: City report: enquiries and latest enquiry for every active sale property in Bengaluru | READ | 9465.956 | 9518.998 | 9500.620 | 9495.191 |
| R20: Growth: new listings per day and running total, June 2026 | READ | 14.206 | 14.121 | 14.074 | 14.134 |
| R21: Experience: average site-visit rating per locality (at least 10 rated visits) | READ | 10.058 | 9.827 | 10.081 | 9.989 |
| R22: Listing moderation console: all listings, newest first, page 2,001 (25 per page) | READ | 32.188 | 32.573 | 33.194 | 32.652 |
| R23: Sign-in with mobile number | READ | 0.023 | 0.018 | 0.019 | 0.020 |
| R24: Buyer protection: under-construction projects whose promised possession date has already passed | READ | 0.128 | 0.144 | 0.125 | 0.132 |
| R25: Funnel: shortlists that turned into an enquiry, per city | READ | 304.892 | 305.236 | 310.505 | 306.878 |
| W01: Post property: owner 1033 lists a 2 BHK for rent in Koramangala | WRITE | 0.773 | 0.465 | 0.479 | 0.572 |
| W02: Price cut: owner 1033 reduces the rent of their most recent active rental by 5% | WRITE | 0.472 | 0.468 | 0.471 | 0.470 |
| W03: Book a site visit: seeker 1042 visits property 6897 on 4 July 2026 at 11:00 | WRITE | 0.491 | 0.443 | 0.446 | 0.460 |
| W04: Nightly job: deactivate active listings older than 120 days | WRITE | 67.012 | 57.127 | 56.237 | 60.125 |
| W05: Owner 1033 marks their oldest active rental as rented | WRITE | 10.351 | 8.578 | 8.261 | 9.063 |
| **Total (sum of all 30)** | | **10076.993** | **10117.653** | **10101.991** | **10098.879** |

---

## 3. Plan Analysis: Scan Types and Performance Bottlenecks

### READ Queries (R01–R25)

- **R01 (Rent search):**
  - **Scan type:** `Seq Scan on properties` | `Seq Scan on localities`
  - **Why it is slow/fast:** Moderate latency (~9.0 ms); performs a full sequential scan across all 120,060 rows of `properties` evaluating multiple filter predicates (`listing_type`, `status`, `bhk`, `price`, `furnishing`) followed by an in-memory Sort without any composite B-tree index on search attributes.
- **R02 (Buy search):**
  - **Scan type:** `Seq Scan on properties` | `Seq Scan on localities`
  - **Why it is slow/fast:** Moderate latency (~7.7 ms); scans all 120k properties in parallel to apply city, type, BHK, and price limits, followed by an explicit Sort on computed expression `(price / carpet_area_sqft)`.
- **R03 (Property page):**
  - **Scan type:** `Index Scan using properties_pkey` | `Index Scan using projects_pkey` | `Index Scan using builders_pkey` | `Index Only Scan using project_amenities_pkey` | `Index Scan using amenities_pkey`
  - **Why it is slow/fast:** Extremely fast (~0.07 ms); navigates entirely through primary key and foreign key B-tree indexes auto-created for PK/UNIQUE constraints to resolve the single property `6897` and its relationships.
- **R04 (Price trends):**
  - **Scan type:** `Seq Scan on localities` | `Seq Scan on properties`
  - **Why it is slow/fast:** Moderate latency (~14.0 ms); requires a full scan of `properties` to compute monthly aggregates and evaluates `EXTRACT(YEAR FROM posted_at)` per row with no composite or functional index on `(locality_id, posted_at)`.
- **R05 (Map view):**
  - **Scan type:** `Seq Scan on properties`
  - **Why it is slow/fast:** Moderate latency (~4.8 ms); performs a sequential scan over `properties` to evaluate bounding box conditions on `latitude` and `longitude` without a spatial / GiST or composite B-tree index.
- **R06 (Owner dashboard):**
  - **Scan type:** `Seq Scan on site_visits` | `Seq Scan on enquiries` | `Seq Scan on properties`
  - **Why it is slow/fast:** Relatively slow (~11.4 ms); scans 100k enquiries, 35k site visits, and 120k properties because foreign keys `enquiries.property_id` and `site_visits.property_id` lack indexes.
- **R07 (Agent app):**
  - **Scan type:** `Seq Scan on site_visits` | `Index Scan using properties_pkey` | `Index Scan using users_pkey`
  - **Why it is slow/fast:** Moderately fast (~2.6 ms); filters `site_visits` by date `scheduled_at::date = '2026-07-01'` via a sequential scan of 35k rows because `scheduled_at` has no index.
- **R08 (Price-drop alerts):**
  - **Scan type:** `Seq Scan on price_changes` | `Index Scan using properties_pkey`
  - **Why it is slow/fast:** Fast (~1.5 ms); scans all 23,425 rows of `price_changes` sequentially to evaluate date range and price reduction calculations, joining back to `properties` via PK index.
- **R09 (Amenity filter):**
  - **Scan type:** `Seq Scan on properties` | `Seq Scan on project_amenities` | `Seq Scan on amenities`
  - **Why it is slow/fast:** Slow (~12.2 ms); performs sequential scans on `properties` and `project_amenities` (6.8k rows) followed by hash joins and group/having filters without an index on `properties.project_id`.
- **R10 (Buyer due diligence):**
  - **Scan type:** `Seq Scan on builders` | `Index Scan using projects_rera_id_key`
  - **Why it is slow/fast:** Extremely fast (~0.04 ms); the `UNIQUE` constraint on `projects.rera_id` created a unique B-tree index, allowing instant single-row index lookup.
- **R11 (Project page):**
  - **Scan type:** `Seq Scan on properties`
  - **Why it is slow/fast:** Slow (~9.5 ms); performs a parallel sequential scan across all 120k properties because foreign key column `properties.project_id` does not have an index.
- **R12 (Lead follow-up):**
  - **Scan type:** `Seq Scan on enquiries` | `Seq Scan on site_visits`
  - **Why it is slow/fast:** Moderate latency (~8.1 ms); checks `NOT EXISTS` across 100k enquiries and 35k site visits via hash anti-join without composite indexes on `(property_id, user_id)`.
- **R13 (Builder partnerships):**
  - **Scan type:** `Seq Scan on projects` | `Seq Scan on properties`
  - **Why it is slow/fast:** Slow (~11.2 ms); anti-join scans all 1,200 projects against all 120k properties because `properties.project_id` lacks a supporting index.
- **R14 (Agent leaderboard):**
  - **Scan type:** `Seq Scan on properties` | `Seq Scan on users`
  - **Why it is slow/fast:** Slow (~15.9 ms); full sequential scans on `properties` and `users` to filter `status IN ('SOLD', 'RENTED')` and group by agent without an index on `(listed_by, status)`.
- **R15 (Investor insights):**
  - **Scan type:** `Seq Scan on properties` | `Seq Scan on localities`
  - **Why it is slow/fast:** Slow (~12.8 ms); scans 120k properties to aggregate rent vs. sale price metrics per locality without an index on `(locality_id, listing_type, status)`.
- **R16 (Search box):**
  - **Scan type:** `Seq Scan on projects`
  - **Why it is slow/fast:** Fast (~0.38 ms); table `projects` has only 1,200 rows so sequential scan is small, though an unindexed `ILIKE` pattern match will not scale on larger tables without trigram indexing (`pg_trgm`).
- **R17 (Owner nudges):**
  - **Scan type:** `Seq Scan on properties` | `Seq Scan on enquiries`
  - **Why it is slow/fast:** Slow (~27.0 ms); scans 120k properties to filter stale listings and executes an anti-join against 100k enquiries without indexes on `properties.posted_at` or `enquiries.property_id`.
- **R18 (Fraud checks):**
  - **Scan type:** `Seq Scan on properties`
  - **Why it is slow/fast:** Slow (~21.0 ms); scans 120k properties and builds an in-memory HashAggregate over 5 grouping columns (`listed_by, locality_id, carpet_area_sqft, floor_no, bhk`) without supporting indexes.
- **R19 (City report):**
  - **Scan type:** `Seq Scan on properties` | `Seq Scan on localities` | `Seq Scan on enquiries`
  - **Why it is slow/fast:** **Major system bottleneck (~9,495.2 ms / ~9.5 s);** executes two correlated scalar subqueries (`count(*)` and `max(created_at)`) on `enquiries` for every active Bengaluru sale property (~4,000 rows), inducing ~8,000 full sequential scans over 100,000 enquiry rows due to missing index on `enquiries.property_id`.
- **R20 (Growth trends):**
  - **Scan type:** `Seq Scan on properties`
  - **Why it is slow/fast:** Slow (~14.1 ms); scans all 120k properties to evaluate `posted_at::date` and aggregate daily counts with a window function running total without an index on `posted_at`.
- **R21 (Experience rating):**
  - **Scan type:** `Seq Scan on properties` | `Seq Scan on site_visits` | `Seq Scan on localities`
  - **Why it is slow/fast:** Slow (~10.0 ms); joins `site_visits` (35k rows), `properties` (120k rows), and `localities` (100 rows) with full sequential scans due to unindexed foreign keys.
- **R22 (Listing moderation console):**
  - **Scan type:** `Seq Scan on properties`
  - **Why it is slow/fast:** Slow (~32.7 ms); scans all 120k rows, performs a full top-N sort on `posted_at DESC`, and discards 50,000 offset rows (`OFFSET 50000 LIMIT 25`) because `posted_at` lacks an index.
- **R23 (Sign-in):**
  - **Scan type:** `Index Scan using users_phone_key`
  - **Why it is slow/fast:** Ultra-fast (~0.02 ms); the `UNIQUE` constraint on `users.phone` automatically generates a B-tree index, giving immediate sub-millisecond point lookup.
- **R24 (Buyer protection):**
  - **Scan type:** `Seq Scan on projects` | `Seq Scan on builders`
  - **Why it is slow/fast:** Fast (~0.13 ms); both `projects` (1,200 rows) and `builders` (150 rows) are very small tables, so sequential scanning overhead is minimal.
- **R25 (Funnel conversion):**
  - **Scan type:** `Index Scan on localities` | `Seq Scan on shortlists` | `Seq Scan on properties` | `Seq Scan on enquiries`
  - **Why it is slow/fast:** **Second major bottleneck (~306.9 ms);** evaluates a correlated `EXISTS (SELECT 1 FROM enquiries ... WHERE property_id = s.property_id AND user_id = s.user_id)` across 69,999 shortlist rows without indexes on `enquiries(property_id, user_id)`.

---

### WRITE Queries (W01–W05)

- **W01 (Post property):**
  - **Scan type:** `(no scan)`
  - **Why it is slow/fast:** Fast (~0.57 ms); single-row `INSERT` into `properties`, evaluating schema constraints and checking PK uniqueness.
- **W02 (Price cut):**
  - **Scan type:** `Index Scan using properties_pkey on properties`
  - **Why it is slow/fast:** Fast (~0.47 ms); updates a single row located by PK index, although the nested scalar subquery `(SELECT max(property_id) ...)` requires a sequential filter over owner 1033's properties.
- **W03 (Book site visit):**
  - **Scan type:** `(no scan)`
  - **Why it is slow/fast:** Fast (~0.46 ms); single-row `INSERT` into `site_visits`, verifying foreign key constraints to `properties` and `users`.
- **W04 (Nightly expiration job):**
  - **Scan type:** `Seq Scan on properties`
  - **Why it is slow/fast:** Slow write (~60.1 ms); must sequentially scan all 120,060 rows of `properties` to find active listings older than 120 days and update their status.
- **W05 (Mark rental as rented):**
  - **Scan type:** `Index Scan using properties_pkey on properties`
  - **Why it is slow/fast:** Moderate (~9.1 ms); target update uses PK index, but the nested subquery `(SELECT min(property_id) ...)` performs a full sequential scan of `properties` to find owner 1033's oldest rental.

---

## 4. Summary & Optimization Priorities for Phase 4 (CP3)

1. **Total Workload Execution Time:** ~10,098.9 ms (~10.1 seconds) across all 30 queries.
2. **Dominant Bottleneck:** Query **`R19`** alone accounts for **~94% of the total workload execution time** (9,495.2 ms out of 10,098.9 ms). The root cause is correlated subqueries executing table scans against `enquiries` without an index on `enquiries.property_id`.
3. **Secondary Bottlenecks:**
   - **`R25`** (~306.9 ms): Correlated subquery over 70,000 shortlists against unindexed `enquiries`.
   - **`W04`** (~60.1 ms): Unindexed batch update scanning all 120k rows of `properties`.
   - **`R22`** (~32.7 ms): Full sort and 50,000-row offset without an index on `properties.posted_at`.
   - **`R17`** (~27.0 ms) & **`R18`** (~21.0 ms): Unindexed anti-joins and heavy 5-column aggregations.
4. **Fast Queries (< 1 ms):** Queries that touch unique or primary key indexes (`R03`, `R10`, `R23`, `W01`, `W02`, `W03`) or very small tables (`R16`, `R24`) run in sub-millisecond time, demonstrating the enormous impact proper B-tree indexing will have when applied to foreign keys and search filter predicates in Phase 4.
