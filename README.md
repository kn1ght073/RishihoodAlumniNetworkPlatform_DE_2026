# Housing.com Property Search Database: DBMS Project

**Course:** Database Management Systems · **Year:** B.Tech 2nd year · **Team size:** 4
**Database:** PostgreSQL 15 or newer · **Final submission:** Mon 23 Nov 2026
**Topics used:** Data types & constraints · Keys & relationships · Normalization · Query execution plans · Indexing · Query optimization · VACUUM/ANALYZE · Partitioning & sharding

## Files in this folder

| Path | What it is |
|------|------------|
| `README.md` | This project brief |
| `seed_data.zip` | 12 CSV files (120,060 property listings): the only input for Phase 2. Unzip it to get `seed_data/` |
| `queries/workload_30.sql` | The 30 queries for Phase 3 (do not edit) |
| `benchmarks/run_benchmark.sh` | Timing script: 3 runs per query, average, raw plans saved |
| `CHECKPOINTS.md` | Checkpoint dates and the files each one needs (DE and AP repos) |

**Getting started:** **clone this repository and push it into your team's DE repo** (the DE repo you submitted in the form); the steps are in [`CHECKPOINTS.md`](CHECKPOINTS.md). Keep the structure shown in [Repository structure](#repository-structure-submit-exactly-this). Unzip `seed_data.zip` inside your project folder, but don't commit the CSV files. Deadlines are in [`CHECKPOINTS.md`](CHECKPOINTS.md). Then begin with Phase 1.

---

## Team details (fill in before you start)

| Role | Name | Enrollment No. | GitHub Username |
|------|------|----------------|-----------------|
| Group Lead | Jai Shastri | 2501010689 | kn1ght073 |
| Member 2 | Darsh Rustagi | 2501010558 | darshr25558-pixel |
| Member 3 | Vansh Kushwaha | 2501010495 | vanshkw |
| Member 4 | Chayan Leekha | 2501010123 | chayanlekha-blip |

**Team No.:** T0079 · **Section:** B · **Repository URL:** [Project Repo](https://github.com/kn1ght073/RishihoodAlumniNetworkPlatform_DE_2026)

---

## How this project works

| Phase | What you do | You submit | Counts toward | Marks |
|-------|-------------|------------|---------------|------:|
| 1 | Understand the problem statements | `docs/01_problem_understanding.md` | Query Execution | 2 |
| 2 | Work out the database schema **from the seed data** and load it | `sql/01_schema.sql`, `sql/02_load_data.sql`, `docs/02_schema_design.md` | Query Execution | 5 |
| 3 | Run the **30 given SQL queries** and record their execution time | `docs/03_baseline_timings.md`, `benchmarks/results/baseline/` | Query Execution | 3 |
| 4 | Optimize the queries and record the new times | `sql/05_indexes.sql`, `sql/06_optimized_queries.sql`, `docs/04_optimization_report.md`, `benchmarks/results/optimized/` | Code Optimization | 16 |
| 5 | Scalability test on the **large dataset** (given later by faculty) and final report | `docs/05_scalability_report.md`, `benchmarks/results/large/` | Code Optimization | 14 |
| | **Total** | | | **40** |

---

## Phase 1: Problem statements

Housing.com helps people **rent** and **buy** homes. Cities are divided into **localities**; **builders** develop **projects** (registered with the regulator **RERA**, either ready to move in or under construction) that offer **amenities** like a gym or pool. Owners and agents list **properties** for sale or rent—apartments inside projects, or standalone houses, villas and plots—with BHK, carpet area, floor, furnishing and price. Seekers shortlist properties, send **enquiries**, book **site visits**, and get alerts when prices drop. You have joined the Housing.com data team.

The current database was put together quickly by an earlier team. It has **no documented schema** (only data exports survive), and the product teams are complaining:

| # | Problem reported | Team | Related queries |
|---|------------------|------|-----------------|
| P1 | "**Rent and buy searches** (filters, price per sq ft, map view, amenity filters) are too slow." | Search | R01, R02, R05, R09, R16 |
| P2 | "**Property and project pages** and RERA lookups lag." | Listings | R03, R10, R11, R24 |
| P3 | "**Owners and agents**: dashboards, site-visit schedules, price changes and status updates are slow." | Owners / Agents | R06, R07, W01, W02, W03, W05 |
| P4 | "**Alerts and follow-ups** (price drops, leads without visits, stale listings) must run every hour." | Engagement | R08, R12, R17 |
| P5 | "The builder-partnerships list of **projects with no listings** is always **empty**." | Builder partnerships | R13 |
| P6 | "**Insights** (price trends, rental yield, agent leaderboard, visit ratings, funnel) time out." | Insights | R04, R14, R15, R21, R25 |
| P7 | "Trust & safety and platform reports are slow, and listings will grow **20×**." | Trust & Safety / Platform | R18, R19, R20, R22, R23, W04 |

**Your job:**
1. Rebuild a correct, well-constrained schema from the data exports (Phase 2).
2. Measure how the 30 most important queries perform today (Phase 3).
3. Make them fast **without changing their results** (Phase 4).
4. Prove the database will survive next year's growth (Phase 5).

**Deliverable for Phase 1** (`docs/01_problem_understanding.md`, at most 1 page):
- For each problem P1–P7, write in your own words what the business needs and which **stakeholder** is affected (home seeker (tenant/buyer), owner, agent, builder, investor, trust & safety, growth).
- Classify each problem as **customer-facing / real-time** or **reporting / analytics**. This decides your performance targets later.
- List any assumptions you make.

---

## Phase 2: Work out the schema from the seed data

You receive **`seed_data.zip`**. Unzip it to get a folder **`seed_data/`** with 12 CSV files, a real export of the production data:

| File | Rows | What it contains |
|------|-----:|------------------|
| `cities.csv` | 10 | Cities |
| `localities.csv` | 100 | Localities of each city |
| `builders.csv` | 150 | Real-estate developers |
| `projects.csv` | 1,200 | Housing projects (with RERA registration when available) |
| `amenities.csv` | 15 | Amenities |
| `project_amenities.csv` | 6,806 | Amenities offered by each project |
| `users.csv` | 40,000 | Users: seekers, owners and agents |
| `properties.csv` | 120,060 | Every property listed from 1 Jan 2025 to 30 Jun 2026 (for rent or sale) |
| `price_changes.csv` | 23,425 | Price changes of listings |
| `enquiries.csv` | 100,000 | Enquiries from seekers |
| `site_visits.csv` | 35,120 | Site visits booked by seekers |
| `shortlists.csv` | 69,999 | Properties shortlisted by seekers |

The first line of every file is the header (column names). Here are the headers and the first rows of each file:

**cities.csv**
```
city_id,city_name,state
1,Bengaluru,Karnataka
2,Mumbai,Maharashtra
```

**localities.csv**
```
locality_id,city_id,locality_name,pincode,center_lat,center_lng
1,1,Koramangala,560011,12.931600,77.554600
2,1,Whitefield,560022,12.971600,77.554600
```

**builders.csv**
```
builder_id,builder_name,founded_year
1,Prestige,1967
2,Sobha,1974
```

**projects.csv**
```
project_id,builder_id,locality_id,project_name,rera_id,possession_status,possession_date,total_units
1,8,14,Heights Phase I 1,MH-RERA-PR-10007919,READY_TO_MOVE,2015-01-18,137
2,15,27,Lakeview Phase I 2,DL-RERA-PR-10015838,READY_TO_MOVE,2015-02-04,174
```

**amenities.csv**
```
amenity_id,amenity_name
1,Gym
2,Swimming Pool
```

**project_amenities.csv**
```
project_id,amenity_id
1,2
1,3
```

**users.csv**
```
user_id,full_name,phone,email,user_type,agent_rera_id,created_at
1,Vivaan Sharma,9600000001,,SEEKER,,2024-11-19 07:00:23+05:30
2,Aditya Sharma,9600000002,aditya.sharma2@gmail.com,SEEKER,,2019-09-28 18:34:19+05:30
```

**properties.csv**
```
property_id,listed_by,project_id,locality_id,listing_type,property_type,bhk,carpet_area_sqft,floor_no,total_floors,furnishing,facing,price,maintenance_monthly,security_deposit,available_from,latitude,longitude,is_verified,status,posted_at
1,15850,313,70,RENT,APARTMENT,2,1283,7,27,FULLY_FURNISHED,NORTH_EAST,23900.00,5540.00,47800.00,2025-01-15,22.484872,88.474366,t,RENTED,2025-01-01 00:00:00+05:30
2,27330,,70,RENT,INDEPENDENT_HOUSE,5,2531,,3,FULLY_FURNISHED,SOUTH_WEST,46500.00,,93000.00,2025-01-12,22.507092,88.493180,t,RENTED,2025-01-01 00:06:33+05:30
```

**price_changes.csv**
```
change_id,property_id,old_price,new_price,changed_at
1,11,35800.00,31800.00,2025-02-05 01:05:31+05:30
2,13,78300.00,68900.00,2025-01-06 01:18:37+05:30
```

**enquiries.csv**
```
enquiry_id,property_id,user_id,channel,message,created_at
1,85207,31805,CALL,,2026-02-13 00:29:42+05:30
2,49892,28624,WHATSAPP,Is the price negotiable?,2025-08-27 21:05:49+05:30
```

**site_visits.csv**
```
visit_id,property_id,user_id,scheduled_at,status,feedback_rating
1,49892,28624,2025-08-29 08:00:00+05:30,COMPLETED,
2,85425,15394,2026-02-08 18:00:00+05:30,COMPLETED,2
```

**shortlists.csv**
```
user_id,property_id,added_at
1,99691,2026-04-09 14:08:52+05:30
1,108609,2026-06-11 01:59:36+05:30
```

Open the files yourself (a spreadsheet, `head`, or `SELECT` after a quick load into a scratch table) and study the data carefully. **Nobody will give you the CREATE TABLE statements.** Working them out *is* the task.

### 2.1 What you must identify (for every table)
1. **Table name and column names.** Use exactly the file names and CSV headers. The 30 queries depend on them.
2. **Data type** of every column. Choose the *right* type, not just `TEXT` everywhere. Think about money, timestamps with a time-zone offset, yes/no columns, small whole numbers, decimals and short codes.
3. **Primary key.** Is it one column, or a combination? (Look closely at `project_amenities` and `shortlists`. `rera_id` is unique but sometimes empty—can a UNIQUE column hold several NULLs?)
4. **Foreign keys.** Which column points to which table? What should happen **ON DELETE** (CASCADE, RESTRICT or SET NULL), and why?
5. **NOT NULL vs NULL.** Some columns are empty in some rows. Find out **when** and **why**, and decide which columns must never be empty. Why do some properties have no `project_id`? When are `bhk`, `floor_no`, `total_floors`, `furnishing`, `maintenance_monthly`, `security_deposit`, `rera_id`, `agent_rera_id` and `feedback_rating` empty?
6. **UNIQUE** columns (natural candidate keys such as emails, phone numbers, codes and handles).
7. **CHECK constraints.** Write at least **12** that the data obeys and the business needs. Look for formats (RERA ids, pincodes), allowed values (listing and property types, furnishing, facing, statuses, user types, channels), ranges (BHK, area, floors), and rules tying columns together (plots have no BHK, a floor can't be above the building, deposits only for rentals, RENTED only for rentals and SOLD only for sales, only agents have an agent RERA id, a rating only after a completed visit).
8. **Relationships and cardinalities** (1:1, 1:N, M:N). Draw the **ER diagram** (image + Mermaid code).
9. **Normal form.** Show that each table is in 3NF/BCNF (list its functional dependencies). Point out any column that is *derived or redundant* (hint: price per sq ft; `properties.price` vs the latest `price_changes.new_price`; a property's `locality_id` vs its project's locality) and say whether keeping it is justified.

### 2.2 Rules for your schema
- Create every table in a schema named **`housing`**: `CREATE SCHEMA housing;` and `SET search_path TO housing;`
- In this phase create **only constraints**: PK, FK, UNIQUE, NOT NULL, CHECK. **Do not create any other index yet.** (PostgreSQL automatically indexes PRIMARY KEY and UNIQUE columns; that's allowed. Note which indexes exist.) Your baseline in Phase 3 must reflect a database *without* tuning.
- Your constraints must accept **all** rows of the seed data. If a load fails, either your constraint is wrong or you found a data problem. Explain which in your design doc.

### 2.3 Load the data
Write `sql/02_load_data.sql` using `\copy`, loading tables in the right order (parents before children):

```sql
SET search_path TO housing;
\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true)
-- ... the other tables, in an order that satisfies your foreign keys
ANALYZE;
```

Then verify the row counts match the table above, and run at least **3 integrity checks** of your own (e.g. "a property inside a project is in the project's locality", "the current price equals the latest price change", "only owners and agents list properties"). Paste the results into `docs/02_schema_design.md`.

### Phase 2 deliverables
- `sql/01_schema.sql`: runs top-to-bottom on an empty database without errors
- `sql/02_load_data.sql`: loads all 12 files without errors
- `docs/02_schema_design.md`: data dictionary (table · column · type · constraint · *why*), ER diagram, FDs and normal form per table, integrity-check results, and every data problem you found

---

## Phase 3: Run the 30 queries and record the time

The file **`queries/workload_30.sql`** contains **30 queries**: 25 reads (`R01`–`R25`) and 5 writes (`W01`–`W05`). They're also listed in the [Appendix](#appendix-the-30-queries). **Do not modify them.** If a query fails, your schema doesn't match the seed data; fix the schema, not the query.

### 3.1 How to measure (everyone must use the same method)
- Run each query with `EXPLAIN (ANALYZE, BUFFERS)` and read the **`Execution Time`** at the bottom.
- Run each query **3 times** and record the **average** of the three `Execution Time` values. Keep all three runs in the raw plan file.
- Write queries (`W01`–`W05`) must be measured inside `BEGIN; … ROLLBACK;` so the data does not change.
- Close other heavy applications while measuring, and use the **same laptop** for Phase 3 and Phase 4.

The helper script does all of this for you:
```bash
./benchmarks/run_benchmark.sh <your_database> baseline
# → benchmarks/results/baseline/summary.csv   (avg, median, min, max, scan types)
# → benchmarks/results/baseline/R01.txt …     (full plans of all 3 runs)
```
> ⚠️ One of the 30 queries takes **several seconds** on the seed data. That's intentional. Let it finish, and don't skip it.

### 3.2 Deliverable: the timing table
In `docs/03_baseline_timings.md`, fill this table for **all 30** queries:

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Rent search: active 2 BHK homes in Koramangala up to ₹40,000/month, furnished or semi-furnished | READ | | | | |
| R02: Buy search: 3 BHK apartments for sale in Pune under ₹1.2 crore, best price per sq ft first | READ | | | | |
| R03: Property page: property 6897 with its project, builder and project amenities | READ | | | | |
| R04: Price trends: average sale price per sq ft of apartments in Whitefield, per month in 2026 | READ | | | | |
| R05: Map view: active rentals inside the visible map area of central Bengaluru | READ | | | | |
| R06: Owner dashboard: owner 1033's listings with enquiry and site-visit counts | READ | | | | |
| R07: Agent app: site visits scheduled on 1 July 2026 for properties listed by user 4723 | READ | | | | |
| R08: Price-drop alerts: active properties whose price fell by 10% or more in June 2026 | READ | | | | |
| R09: Amenity filter: active properties in projects that have a gym AND a swimming pool AND power backup | READ | | | | |
| R10: Buyer due diligence: look up a project by its RERA registration id | READ | | | | |
| R11: Project page: available listings in project 217 by BHK with the price range | READ | | | | |
| R12: Lead follow-up: June 2026 enquiries with no site visit booked for that property by that user | READ | | | | |
| R13: Builder partnerships: projects with no property listed on Housing.com | READ | | | | |
| R14: Agent leaderboard: agents with the most properties sold or rented in 2026 | READ | | | | |
| R15: Investor insights: rental yield by Bengaluru locality (yearly rent per sq ft ÷ sale price per sq ft) | READ | | | | |
| R16: Search box: projects with "greens" in the name | READ | | | | |
| R17: Owner nudges: active listings older than 90 days that have never received an enquiry | READ | | | | |
| R18: Fraud checks: the same flat (locality, area, floor, BHK) listed more than once by the same lister | READ | | | | |
| R19: City report: enquiries and latest enquiry for every active sale property in Bengaluru | READ | | | | |
| R20: Growth: new listings per day and running total, June 2026 | READ | | | | |
| R21: Experience: average site-visit rating per locality (at least 10 rated visits) | READ | | | | |
| R22: Listing moderation console: all listings, newest first, page 2,001 (25 per page) | READ | | | | |
| R23: Sign-in with mobile number | READ | | | | |
| R24: Buyer protection: under-construction projects whose promised possession date has already passed | READ | | | | |
| R25: Funnel: shortlists that turned into an enquiry, per city | READ | | | | |
| W01: Post property: owner 1033 lists a 2 BHK for rent in Koramangala | WRITE | | | | |
| W02: Price cut: owner 1033 reduces the rent of their most recent active rental by 5% | WRITE | | | | |
| W03: Book a site visit: seeker 1042 visits property 6897 on 4 July 2026 at 11:00 | WRITE | | | | |
| W04: Nightly job: deactivate active listings older than 120 days | WRITE | | | | |
| W05: Owner 1033 marks their oldest active rental as rented | WRITE | | | | |
| **Total (sum of all 30)** | | | | | |

Below the table, add for each query the **scan type** from the plan (Seq Scan, Index Scan, …) and one line on **why** it is slow or fast.

---

## Phase 4: Optimize the queries

Make the queries faster. **The results must stay the same** (same rows; order matters only where the query has an `ORDER BY`).

### 4.1 Techniques you may use
| Technique | Example |
|-----------|---------|
| B-tree index (single / composite) | the right column **order** matters: equality columns first, then range/sort |
| Partial index | index only the rows a query needs (e.g. a rare status) |
| Covering index | `INCLUDE (...)` so the table is never visited (Index Only Scan) |
| Expression index | index the exact expression used in `WHERE` |
| GIN index | for `ILIKE '%text%'` (extension `pg_trgm`), arrays or full-text search |
| BRIN index | for huge tables stored in time order |
| Query rewrite | sargable date ranges instead of functions on columns; `NOT EXISTS` instead of `NOT IN`; joins instead of correlated subqueries; keyset instead of `OFFSET` pagination; `UNION ALL` instead of `OR` across columns |
| VACUUM / ANALYZE | fresh statistics and visibility maps |
| Summary table / materialized view | for heavy reports that don't need live data (state how it's refreshed) |

**Not allowed:** changing the data, deleting rows, changing PostgreSQL server settings to hide the problem (e.g. huge `work_mem`, `enable_seqscan = off`), or caching results outside the database.

### 4.2 How to work
1. Put every index in `sql/05_indexes.sql`, each with a comment: **which queries it serves and why this type and column order**.
2. Put rewritten queries in `sql/06_optimized_queries.sql`. Copy `queries/workload_30.sql` and change **only** the queries you rewrite, keeping the `-- @R01` markers.
3. **Prove the results are unchanged** for every rewritten query (compare row counts, plus a checksum or an `EXCEPT` query). Put the proof in your report.
4. Benchmark again with the same method:
```bash
./benchmarks/run_benchmark.sh <your_database> optimized 5 sql/06_optimized_queries.sql
```
> 🔎 **Read the results, not just the timings.** At least one of the 30 original queries returns a **wrong answer** because of a subtle SQL rule about NULLs. Find it, explain it, and fix it. This is worth marks.

### 4.3 Deliverable: the optimization table
In `docs/04_optimization_report.md`:

| Query | Before (ms) | Problem found in the plan | Optimization applied | After (ms) | Improvement | Same result? |
|-------|------------:|---------------------------|----------------------|-----------:|------------:|:------------:|
| R01 | | e.g. Seq Scan on 120k properties | e.g. partial index on `properties(locality_id, bhk, price) WHERE status = 'ACTIVE' AND listing_type = 'RENT'` | | e.g. 99% (80×) | ✅ |
| … all 30 … | | | | | | |
| **Total** | | | | | | |

Improvement % = (before − after) / before × 100

Also include:
- **Before/after `EXPLAIN` plans** for your 5 biggest improvements
- **Write overhead:** which write queries got **slower** because of your indexes, by how much, and whether that's acceptable
- **Index storage:** the size of each index you created (`pg_relation_size`) compared with its table
- **Queries you could not speed up**, and why (an honest "this query must read most of the table" earns marks)

---

## Phase 5: Scalability report (large dataset round)

Your optimizations worked on 120,060 property listings. Next year the business expects **20× the volume**.

By **Thu 19 Nov 2026**, faculty will release **`large_data.zip`**: the same 12 CSV files with about **20× the rows** (≈ 2,401,000 properties, ≈ 2,000,000 enquiries, ≈ 1,400,000 shortlists, ≈ 702,000 site visits, ≈ 800,000 users). Until then, work on the design part of the report.

### 5.1 What to do with the large dataset
1. Create a new database. Run **your** `01_schema.sql`, load `large_data/` with your load script (change the folder name only), then run **your** `05_indexes.sql` and `ANALYZE`.
2. Run your **optimized** queries (`sql/06_optimized_queries.sql`). **Do not run the original 30 on the large data.** Some of them could run for a very long time.
   - R22 pages with `OFFSET`; if you replaced it with keyset pagination, explain how the "last seen" value is chosen for the large data.
3. Record the times and compare with your Phase 4 results on the seed data.

| Query | Optimized on seed (ms) | Optimized on large (ms) | Growth (large ÷ seed) | Meets target? | If not, what you changed |
|-------|------------------------:|------------------------:|----------------------:|:-------------:|--------------------------|
| R01 | | | | | |
| … all 30 … | | | | | |

### 5.2 Performance targets on the large dataset
| Query group | Queries | Target (average of 3 runs) |
|-------------|---------|----------------:|
| Real-time / user-facing | R01, R02, R03, R05, R06, R07, R10, R11, R23, W01, W02, W03, W05 | **under 5 ms** |
| Interactive tools | R08, R09, R12, R13, R16, R17, R22, R24 | **under 250 ms** |
| Reports and analytics | R04, R14, R15, R18, R19, R20, R21, R25 | **under 5,000 ms** |
| Batch jobs | W04 | **under 1,000 ms** |

If a query misses its target, **find out why from the plan and fix it.** A query that was fast on the seed data can become slow on large data for reasons that only appear at scale. Show the before/after plans for every fix.

### 5.3 Deliverable: `docs/05_scalability_report.md`
1. **Results table** (above), with every target met or explained.
2. **Growth analysis.** Group your queries by how their time grew when the data grew 20×:
   - *stayed about the same* (why? e.g. index lookups grow with log n)
   - *grew about 20×* (why? e.g. they read a fixed *share* of the table)
   - *grew more than 20×* (why, and what you did about it)
3. **What broke at scale** and how you fixed it (plans before/after).
4. **Storage:** total database size, table vs index size, on seed and large data.
5. **Architecture for 100×:** explain with numbers from your own measurements:
   - **Partitioning:** which table, by which column (RANGE / LIST / HASH), and why. Write the DDL for `properties`, show partition pruning with `EXPLAIN`, and note the primary-key rule for partitioned tables.
   - **Sharding:** Would you shard by city/locality, by lister, or by listing type? Searches are local—but agent leaderboards and funnels span all cities. Which queries become cross-shard, and how would you handle them?
   - **Read replicas and caching:** which of the 30 queries you would send to a replica or cache, and which must hit the primary.
   - **Maintenance:** VACUUM/autovacuum settings for `properties`, archiving old data, refreshing summary tables.
6. **Conclusion:** is your database ready for next year? What are the remaining risks?

---

## Repository structure (submit exactly this)

```
housing-dbms-<team-no>/
├── README.md                          # team table, how to run, headline numbers
├── team.json                          # group lead, members, enrollment numbers
├── docs/
│   ├── 01_problem_understanding.md
│   ├── 02_schema_design.md
│   ├── 03_baseline_timings.md
│   ├── 04_optimization_report.md
│   └── 05_scalability_report.md
├── diagrams/
│   └── er_diagram.png
├── sql/
│   ├── 01_schema.sql
│   ├── 02_load_data.sql
│   ├── 05_indexes.sql
│   ├── 06_optimized_queries.sql
│   └── 08_partitioning.sql
├── queries/
│   └── workload_30.sql                # given; do not edit
└── benchmarks/
    ├── run_benchmark.sh               # given
    └── results/
        ├── baseline/                  # Phase 3: summary.csv + raw plans
        ├── optimized/                 # Phase 4
        └── large/                     # Phase 5
```

`team.json`:
```json
{
  "team_number": "",
  "group_lead": { "name": "", "enrollment_no": "", "github": "" },
  "members": [
    { "name": "", "enrollment_no": "", "github": "" },
    { "name": "", "enrollment_no": "", "github": "" },
    { "name": "", "enrollment_no": "", "github": "" }
  ],
  "postgres_version": "",
  "laptop_used_for_benchmarks": ""
}
```

**Do not commit the CSV files** (`seed_data/`, `large_data/`); add them to `.gitignore`. They are too large and we already have them.

---

## Timeline

| Due | Work | Checkpoint |
|-----|------|------------|
| Tue 3 Nov 2026 | Clone this repo into your team's DE repo, add members, commit `team.json` | **CP0** Setup |
| Mon 16 Nov 2026 | Phase 1 + Phase 2 (schema, load, ER, data dictionary) | **CP1** Schema loads all seed data with no errors |
| Tue 17 Nov 2026 | Phase 3 (baseline, 3 runs, average) + start Phase 4 | **CP2** Baseline table for all 30 queries committed |
| Thu 19 Nov 2026 | Phase 4 (indexes, rewrites, wrong-result query) | **CP3** Optimization table committed |
| Mon 23 Nov 2026 | Phase 5 on the large dataset + final report | **CP4 Final submission:** last commit on the default branch |
| Wed 25 – Thu 26 Nov 2026 | Individual analysis, in class time | **CP5** Individual analysis |

Full list of files per checkpoint, including the AP repo: [`CHECKPOINTS.md`](CHECKPOINTS.md).

---

## Evaluation (40 marks)

These 40 marks are the DE part of the project: **Query Execution (10)** and **Code Optimization (30)**.
The AP project (20) and your Individual analysis (40) make up the rest of the 100.

| Phase | Criteria | Marks |
|-------|----------|------:|
| | **Query Execution** | **10** |
| 1 | Problems understood, stakeholders and query groups correctly identified | 2 |
| 2 | Correct data types (1), keys and foreign keys with justified delete rules (1), ≥12 meaningful CHECK / NOT NULL / UNIQUE constraints (1), ER diagram + normal-form analysis (1), data loads cleanly + integrity checks (1) | 5 |
| 3 | All 30 queries measured with the required method: 3 runs, average (1), raw plans committed (1), scan type and reason for each query (1) | 3 |
| | **Code Optimization** | **30** |
| 4 | Speed-up achieved with appropriate techniques (6), every index justified (3), results proven unchanged (2), wrong-result query found and explained (2), write overhead and index storage reported (3) | 16 |
| 5 | Large-dataset results with all targets met or explained (4), growth analysis (3), scale-only problems found and fixed (3), partitioning DDL + sharding/replica design backed by your numbers (4) | 14 |
| | **Total** | **40** |

**Integrity rules**
- Every number in your reports must match the raw plan files in `benchmarks/results/`. Copied or invented timings make the whole phase score 0.
- Every member must have commits; the commit history is checked.
- You may use AI tools to learn, but you must be able to explain every index and rewrite in your individual analysis.

---

## Appendix: the 30 queries

These are identical to `queries/workload_30.sql`. Use the file, not copy-paste from this page.

**R01: Rent search: active 2 BHK homes in Koramangala up to ₹40,000/month, furnished or semi-furnished**
```sql
SELECT p.property_id, p.price AS rent, p.carpet_area_sqft, p.furnishing, p.available_from
FROM properties p
JOIN localities l ON l.locality_id = p.locality_id
WHERE l.locality_name = 'Koramangala' AND l.city_id = 1
  AND p.listing_type = 'RENT' AND p.status = 'ACTIVE'
  AND p.bhk = 2 AND p.price <= 40000
  AND p.furnishing IN ('SEMI_FURNISHED', 'FULLY_FURNISHED')
ORDER BY p.price;
```

**R02: Buy search: 3 BHK apartments for sale in Pune under ₹1.2 crore, best price per sq ft first**
```sql
SELECT p.property_id, l.locality_name, p.price, p.carpet_area_sqft,
       round(p.price / p.carpet_area_sqft, 0) AS price_per_sqft
FROM properties p
JOIN localities l ON l.locality_id = p.locality_id
WHERE l.city_id = 6
  AND p.listing_type = 'SALE' AND p.status = 'ACTIVE'
  AND p.property_type = 'APARTMENT' AND p.bhk = 3
  AND p.price < 12000000
ORDER BY price_per_sqft
LIMIT 30;
```

**R03: Property page: property 6897 with its project, builder and project amenities**
```sql
SELECT p.property_id, p.price, p.bhk, p.carpet_area_sqft, pj.project_name, b.builder_name,
       string_agg(a.amenity_name, ', ' ORDER BY a.amenity_name) AS amenities
FROM properties p
LEFT JOIN projects pj          ON pj.project_id = p.project_id
LEFT JOIN builders b           ON b.builder_id = pj.builder_id
LEFT JOIN project_amenities pa ON pa.project_id = p.project_id
LEFT JOIN amenities a          ON a.amenity_id = pa.amenity_id
WHERE p.property_id = 6897
GROUP BY p.property_id, p.price, p.bhk, p.carpet_area_sqft, pj.project_name, b.builder_name;
```

**R04: Price trends: average sale price per sq ft of apartments in Whitefield, per month in 2026**
```sql
SELECT date_trunc('month', p.posted_at) AS month, count(*) AS listings,
       round(avg(p.price / p.carpet_area_sqft), 0) AS avg_price_per_sqft
FROM properties p
JOIN localities l ON l.locality_id = p.locality_id
WHERE l.locality_name = 'Whitefield'
  AND p.listing_type = 'SALE' AND p.property_type = 'APARTMENT'
  AND EXTRACT(YEAR FROM p.posted_at) = 2026
GROUP BY 1
ORDER BY 1;
```

**R05: Map view: active rentals inside the visible map area of central Bengaluru**
```sql
SELECT property_id, latitude, longitude, price, bhk
FROM properties
WHERE listing_type = 'RENT' AND status = 'ACTIVE'
  AND latitude BETWEEN 12.90 AND 13.00
  AND longitude BETWEEN 77.55 AND 77.65
LIMIT 200;
```

**R06: Owner dashboard: owner 1033's listings with enquiry and site-visit counts**
```sql
SELECT p.property_id, p.listing_type, p.status, p.price,
       count(DISTINCT e.enquiry_id) AS enquiries, count(DISTINCT v.visit_id) AS visits
FROM properties p
LEFT JOIN enquiries e   ON e.property_id = p.property_id
LEFT JOIN site_visits v ON v.property_id = p.property_id
WHERE p.listed_by = 1033
GROUP BY p.property_id, p.listing_type, p.status, p.price
ORDER BY enquiries DESC;
```

**R07: Agent app: site visits scheduled on 1 July 2026 for properties listed by user 4723**
```sql
SELECT v.visit_id, v.property_id, v.scheduled_at, u.full_name AS visitor, u.phone
FROM site_visits v
JOIN properties p ON p.property_id = v.property_id
JOIN users u      ON u.user_id = v.user_id
WHERE p.listed_by = 4723
  AND DATE(v.scheduled_at) = '2026-07-01'
ORDER BY v.scheduled_at;
```

**R08: Price-drop alerts: active properties whose price fell by 10% or more in June 2026**
```sql
SELECT c.property_id, c.old_price, c.new_price, round(100 * (1 - c.new_price / c.old_price), 1) AS drop_pct
FROM price_changes c
JOIN properties p ON p.property_id = c.property_id AND p.status = 'ACTIVE'
WHERE c.changed_at >= '2026-06-01' AND c.changed_at < '2026-07-01'
  AND c.new_price <= c.old_price * 0.9
ORDER BY drop_pct DESC;
```

**R09: Amenity filter: active properties in projects that have a gym AND a swimming pool AND power backup**
```sql
SELECT p.property_id, p.price, p.project_id
FROM properties p
WHERE p.status = 'ACTIVE'
  AND p.project_id IN (SELECT pa.project_id
                       FROM project_amenities pa JOIN amenities a ON a.amenity_id = pa.amenity_id
                       WHERE a.amenity_name IN ('Gym', 'Swimming Pool', 'Power Backup')
                       GROUP BY pa.project_id
                       HAVING count(*) = 3)
ORDER BY p.price
LIMIT 50;
```

**R10: Buyer due diligence: look up a project by its RERA registration id**
```sql
SELECT p.project_id, p.project_name, b.builder_name, p.possession_status, p.possession_date
FROM projects p
JOIN builders b ON b.builder_id = p.builder_id
WHERE p.rera_id = 'TS-RERA-PR-11726342';
```

**R11: Project page: available listings in project 217 by BHK with the price range**
```sql
SELECT bhk, listing_type, count(*) AS listings, min(price) AS min_price, max(price) AS max_price
FROM properties
WHERE project_id = 217 AND status = 'ACTIVE'
GROUP BY bhk, listing_type
ORDER BY bhk, listing_type;
```

**R12: Lead follow-up: June 2026 enquiries with no site visit booked for that property by that user**
```sql
SELECT e.enquiry_id, e.property_id, e.user_id, e.created_at
FROM enquiries e
WHERE e.created_at >= '2026-06-01' AND e.created_at < '2026-06-24'
  AND NOT EXISTS (SELECT 1 FROM site_visits v WHERE v.property_id = e.property_id AND v.user_id = e.user_id)
ORDER BY e.created_at;
```

**R13: Builder partnerships: projects with no property listed on Housing.com**
```sql
SELECT pj.project_id, pj.project_name, pj.possession_status
FROM projects pj
WHERE pj.project_id NOT IN (SELECT p.project_id FROM properties p);
```

**R14: Agent leaderboard: agents with the most properties sold or rented in 2026**
```sql
SELECT u.user_id, u.full_name, count(*) AS deals
FROM properties p
JOIN users u ON u.user_id = p.listed_by AND u.user_type = 'AGENT'
WHERE p.status IN ('SOLD', 'RENTED') AND p.posted_at >= '2026-01-01'
GROUP BY u.user_id, u.full_name
ORDER BY deals DESC
LIMIT 20;
```

**R15: Investor insights: rental yield by Bengaluru locality (yearly rent per sq ft ÷ sale price per sq ft)**
```sql
SELECT l.locality_name,
       round(avg(p.price / p.carpet_area_sqft) FILTER (WHERE p.listing_type = 'RENT') * 12, 1) AS yearly_rent_psf,
       round(avg(p.price / p.carpet_area_sqft) FILTER (WHERE p.listing_type = 'SALE'), 0) AS sale_psf,
       round(100 * 12 * avg(p.price / p.carpet_area_sqft) FILTER (WHERE p.listing_type = 'RENT')
                 / avg(p.price / p.carpet_area_sqft) FILTER (WHERE p.listing_type = 'SALE'), 2) AS yield_pct
FROM properties p
JOIN localities l ON l.locality_id = p.locality_id
WHERE l.city_id = 1 AND p.property_type = 'APARTMENT'
GROUP BY l.locality_name
ORDER BY yield_pct DESC;
```

**R16: Search box: projects with "greens" in the name**
```sql
SELECT project_id, project_name, possession_status
FROM projects
WHERE project_name ILIKE '%greens%'
ORDER BY project_name
LIMIT 30;
```

**R17: Owner nudges: active listings older than 90 days that have never received an enquiry**
```sql
SELECT p.property_id, p.listed_by, p.posted_at
FROM properties p
WHERE p.status = 'ACTIVE'
  AND p.posted_at < TIMESTAMPTZ '2026-07-01 00:00:00+05:30' - interval '90 days'
  AND NOT EXISTS (SELECT 1 FROM enquiries e WHERE e.property_id = p.property_id)
ORDER BY p.posted_at;
```

**R18: Fraud checks: the same flat (locality, area, floor, BHK) listed more than once by the same lister**
```sql
SELECT listed_by, locality_id, carpet_area_sqft, floor_no, bhk, count(*) AS copies
FROM properties
WHERE status = 'ACTIVE'
GROUP BY listed_by, locality_id, carpet_area_sqft, floor_no, bhk
HAVING count(*) > 1
ORDER BY copies DESC;
```

**R19: City report: enquiries and latest enquiry for every active sale property in Bengaluru**
```sql
SELECT p.property_id, p.price,
       (SELECT count(*) FROM enquiries e WHERE e.property_id = p.property_id) AS enquiries,
       (SELECT max(e.created_at) FROM enquiries e WHERE e.property_id = p.property_id) AS last_enquiry_at
FROM properties p
JOIN localities l ON l.locality_id = p.locality_id
WHERE l.city_id = 1 AND p.listing_type = 'SALE' AND p.status = 'ACTIVE'
ORDER BY enquiries DESC;
```

**R20: Growth: new listings per day and running total, June 2026**
```sql
SELECT day, listings, sum(listings) OVER (ORDER BY day) AS running_total
FROM (
    SELECT posted_at::date AS day, count(*) AS listings
    FROM properties
    WHERE posted_at::date BETWEEN '2026-06-01' AND '2026-06-30'
    GROUP BY 1
) d
ORDER BY day;
```

**R21: Experience: average site-visit rating per locality (at least 10 rated visits)**
```sql
SELECT l.locality_name, round(avg(v.feedback_rating), 2) AS avg_rating, count(*) AS rated_visits
FROM site_visits v
JOIN properties p ON p.property_id = v.property_id
JOIN localities l ON l.locality_id = p.locality_id
WHERE v.feedback_rating IS NOT NULL
GROUP BY l.locality_name
HAVING count(*) >= 10
ORDER BY avg_rating DESC;
```

**R22: Listing moderation console: all listings, newest first, page 2,001 (25 per page)**
```sql
SELECT property_id, listed_by, listing_type, status, price, posted_at
FROM properties
ORDER BY posted_at DESC
OFFSET 50000
LIMIT 25;
```

**R23: Sign-in with mobile number**
```sql
SELECT user_id, full_name, user_type
FROM users
WHERE phone = '9600001042';
```

**R24: Buyer protection: under-construction projects whose promised possession date has already passed**
```sql
SELECT pj.project_id, pj.project_name, b.builder_name, pj.possession_date
FROM projects pj
JOIN builders b ON b.builder_id = pj.builder_id
WHERE pj.possession_status = 'UNDER_CONSTRUCTION'
  AND pj.possession_date < '2026-07-01'
ORDER BY pj.possession_date;
```

**R25: Funnel: shortlists that turned into an enquiry, per city**
```sql
SELECT l.city_id, count(*) AS shortlists,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM enquiries e WHERE e.property_id = s.property_id AND e.user_id = s.user_id)) AS converted
FROM shortlists s
JOIN properties p ON p.property_id = s.property_id
JOIN localities l ON l.locality_id = p.locality_id
GROUP BY l.city_id
ORDER BY l.city_id;
```

**W01: Post property: owner 1033 lists a 2 BHK for rent in Koramangala**
```sql
INSERT INTO properties (property_id, listed_by, locality_id, listing_type, property_type, bhk, carpet_area_sqft, floor_no,
                        total_floors, furnishing, facing, price, security_deposit, available_from, latitude, longitude,
                        status, posted_at)
VALUES (90000001, 1033, 1, 'RENT', 'APARTMENT', 2, 1050, 3, 8, 'SEMI_FURNISHED', 'EAST', 38000, 114000, '2026-07-15',
        12.931200, 77.627000, 'ACTIVE', '2026-07-01 10:00:00+05:30');
```

**W02: Price cut: owner 1033 reduces the rent of their most recent active rental by 5%**
```sql
UPDATE properties
SET price = round(price * 0.95, -2)
WHERE property_id = (SELECT max(property_id) FROM properties
                     WHERE listed_by = 1033 AND status = 'ACTIVE' AND listing_type = 'RENT');
```

**W03: Book a site visit: seeker 1042 visits property 6897 on 4 July 2026 at 11:00**
```sql
INSERT INTO site_visits (visit_id, property_id, user_id, scheduled_at, status)
VALUES (90000001, 6897, 1042, '2026-07-04 11:00:00+05:30', 'SCHEDULED');
```

**W04: Nightly job: deactivate active listings older than 120 days**
```sql
UPDATE properties
SET status = 'INACTIVE'
WHERE status = 'ACTIVE'
  AND posted_at < TIMESTAMPTZ '2026-07-01 00:00:00+05:30' - interval '120 days';
```

**W05: Owner 1033 marks their oldest active rental as rented**
```sql
UPDATE properties
SET status = 'RENTED'
WHERE property_id = (SELECT min(property_id) FROM properties
                     WHERE listed_by = 1033 AND status = 'ACTIVE' AND listing_type = 'RENT');
```
