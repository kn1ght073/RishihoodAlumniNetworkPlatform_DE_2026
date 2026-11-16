# Schema Design

**Project:** Housing.com Property Search Database · **Team T0079** · **Phase 2**

Our schema was reverse-engineered from the 12 CSV exports in `seed_data.zip`
(10 cities, 100 localities, 150 builders, 1,200 projects, 15 amenities, 6,806
project-amenity pairs, 40,000 users, 120,060 properties, 23,425 price changes,
100,000 enquiries, 35,120 site visits, 69,999 shortlists). Everything below was
**verified by actually loading the data** into PostgreSQL 16 and running the checks
in §6 — no constraint rejects a single seed row, and all 30 workload queries run
unmodified.

- DDL: [`sql/01_schema.sql`](../sql/01_schema.sql) (constraints only — no tuning indexes)
- Load: [`sql/02_load_data.sql`](../sql/02_load_data.sql) (`\copy`, parents before children, `ANALYZE` at the end)
- ER diagram: [`diagrams/er_diagram.svg`]

Run order:

```bash
psql -d <your_database> -f sql/01_schema.sql
psql -d <your_database> -f sql/02_load_data.sql   # from the repo root
```

---

## 1. Tables and relationships

| Table | Rows | Purpose | PK | Key relationships |
|---|---:|---|---|---|
| `cities` | 10 | Cities we operate in | `city_id` | — |
| `localities` | 100 | City neighbourhoods | `locality_id` | `city_id` → cities (RESTRICT) |
| `builders` | 150 | Real-estate developers | `builder_id` | — |
| `projects` | 1,200 | RERA-registered developments | `project_id` | `builder_id` → builders, `locality_id` → localities |
| `amenities` | 15 | Amenity catalogue | `amenity_id` | — |
| `project_amenities` | 6,806 | M:N bridge | `(project_id, amenity_id)` | → projects, → amenities (CASCADE) |
| `users` | 40,000 | Seekers, owners, agents | `user_id` | — |
| `properties` | 120,060 | Every listing | `property_id` | `listed_by` → users, `project_id` → projects (nullable), `locality_id` → localities |
| `price_changes` | 23,425 | Listing price history | `change_id` | `property_id` → properties (CASCADE) |
| `enquiries` | 100,000 | Leads from seekers | `enquiry_id` | → properties, → users (CASCADE) |
| `site_visits` | 35,120 | Booked visits | `visit_id` | → properties, → users (CASCADE) |
| `shortlists` | 69,999 | M:N user × property | `(user_id, property_id)` | → users, → properties (CASCADE) |

**ON DELETE choices** (per the brief, decided per relationship):

- **RESTRICT** for geography and identity (`localities.city_id`, `projects.builder_id`,
  `projects.locality_id`, `properties.listed_by`, `properties.locality_id`): a city with
  localities, or a user who listed properties, must not vanish silently — deleting them
  would orphan live listings and RERA-registered projects.
- **CASCADE** for user activity and catalogue bridges (`price_changes`, `enquiries`,
  `site_visits`, `shortlists`, `project_amenities`): activity rows have no meaning
  without their property/user, so they follow it. This also keeps W01/W03-style write
  paths and future deletes simple.
- **SET NULL** for `properties.project_id`: if a project is ever removed, its *listings*
  are real homes that survive — they become standalone listings instead of disappearing.

## 2. Data dictionary

Types were chosen from the data, not defaulted to TEXT: money as `NUMERIC(12,2)`
(exact decimal — never float for prices), coordinates as `NUMERIC(10,7)`
(7 decimal places is ~1 cm of ground precision, the resolution the export uses),
timestamps with offsets as `TIMESTAMPTZ` (every CSV stamp carries `+05:30`),
yes/no as `BOOLEAN`, short enumerated codes as `VARCHAR` + CHECK.

### cities
| Column | Type | Constraint | Why |
|---|---|---|---|
| `city_id` | INT | PK | Small surrogate key, ids 1–10 |
| `city_name` | VARCHAR(100) | NOT NULL, UNIQUE | Business key: we operate once per city |
| `state` | VARCHAR(100) | NOT NULL | Always present in the export |

### localities
| Column | Type | Constraint | Why |
|---|---|---|---|
| `locality_id` | INT | PK | Surrogate key |
| `city_id` | INT | NOT NULL, FK → cities (RESTRICT) | A locality belongs to exactly one city; no orphan localities |
| `locality_name` | VARCHAR(150) | NOT NULL, UNIQUE with `city_id` | Same name may repeat across cities, never within one (0 duplicates verified) |
| `pincode` | VARCHAR(10) | NOT NULL, CHECK `^[0-9]{6}$` | Indian postal codes are 6 digits; kept VARCHAR so leading zeros survive |
| `center_lat` / `center_lng` | NUMERIC(10,7) | nullable | Optional map centre for the locality page |

### builders
| Column | Type | Constraint | Why |
|---|---|---|---|
| `builder_id` | INT | PK | Surrogate key |
| `builder_name` | VARCHAR(150) | NOT NULL, UNIQUE | No duplicate builders (0 duplicates verified) |
| `founded_year` | INT | CHECK 1800–2026 | Sanity range; all 150 rows have values (1960–…) |

### projects
| Column | Type | Constraint | Why |
|---|---|---|---|
| `project_id` | INT | PK | Surrogate key |
| `builder_id` | INT | NOT NULL, FK → builders (RESTRICT) | Every project has a developer (0 NULLs in export) |
| `locality_id` | INT | NOT NULL, FK → localities (RESTRICT) | Every project is located somewhere |
| `project_name` | VARCHAR(200) | NOT NULL | Display name; not unique across cities |
| `rera_id` | VARCHAR(100) | UNIQUE, CHECK `^[A-Z]{2}-RERA-PR-[0-9]{8}$` or NULL | Registration is unique when present; **171 of 1,200 rows are NULL** (unregistered/legacy) — PostgreSQL UNIQUE permits many NULLs, exactly what the brief asks about |
| `possession_status` | VARCHAR(50) | NOT NULL, CHECK in {`READY_TO_MOVE`, `UNDER_CONSTRUCTION`} | Only these two occur |
| `possession_date` | DATE | NOT NULL | Always present in export |
| `total_units` | INT | NOT NULL, CHECK > 0 | A project has at least one unit (range 100–999) |

### amenities / project_amenities
| Column | Type | Constraint | Why |
|---|---|---|---|
| `amenity_id` | INT | PK | Surrogate key |
| `amenity_name` | VARCHAR(100) | NOT NULL, UNIQUE | No duplicate catalogue entries |
| `(project_id, amenity_id)` | INT, INT | composite PK, both FK (CASCADE) | The M:N bridge: a project offers each amenity at most once; deleting either side cleans the pair |

### users
| Column | Type | Constraint | Why |
|---|---|---|---|
| `user_id` | INT | PK | Surrogate key |
| `full_name` | VARCHAR(150) | NOT NULL | Always present |
| `phone` | VARCHAR(20) | NOT NULL, UNIQUE, CHECK `^[0-9]{10}$` | **The sign-in key (R23)**; all 40,000 rows are unique 10-digit numbers |
| `email` | VARCHAR(255) | UNIQUE, CHECK email pattern or NULL | 24,010 rows have email, 15,990 don't — optional but never duplicated when present |
| `user_type` | VARCHAR(30) | NOT NULL, CHECK in {`SEEKER`, `OWNER`, `AGENT`} | The three roles in the export |
| `agent_rera_id` | VARCHAR(100) | UNIQUE, CHECK `^AG-RERA-[0-9]{8}$` or NULL, CHECK NULL unless AGENT | Only agents carry one; every agent has one (2,049 distinct agent ids, 0 violations) |
| `created_at` | TIMESTAMPTZ | NOT NULL | Account creation, offset preserved |

### properties (the fact table, 120,060 rows)
| Column | Type | Constraint | Why |
|---|---|---|---|
| `property_id` | INT | PK | Surrogate key |
| `listed_by` | INT | NOT NULL, FK → users (RESTRICT) | Every listing has an owner/agent lister (99,674 by OWNERs, 20,386 by AGENTs; 0 by SEEKERs) |
| `project_id` | INT | FK → projects (SET NULL), nullable | NULL = standalone house/villa/plot: **54,009 rows**, matches the standalone property types |
| `locality_id` | INT | NOT NULL, FK → localities (RESTRICT) | Searches are locality-first (R01, R02, R15) |
| `listing_type` | VARCHAR(30) | NOT NULL, CHECK {`RENT`, `SALE`} | The two sides of the marketplace |
| `property_type` | VARCHAR(50) | NOT NULL, CHECK {`APARTMENT`, `INDEPENDENT_HOUSE`, `PLOT`, `VILLA`} | Four kinds, exactly as in the export |
| `bhk` | INT | CHECK 1–5 or NULL | 1–5 in data; NULL for every PLOT (see data problems, §7) |
| `carpet_area_sqft` | NUMERIC(10,2) | NOT NULL, CHECK > 0 | Every listing has an area (730–4,199 sq ft) |
| `floor_no` | INT | CHECK 0 ≤ floor ≤ total_floors, or NULL | 0 = ground floor; NULL for standalone homes; never above `total_floors` (0 violations) |
| `total_floors` | INT | CHECK > 0 or NULL | Building height for floors-in-project listings |
| `furnishing` | VARCHAR(30) | CHECK {`UNFURNISHED`, `SEMI_FURNISHED`, `FULLY_FURNISHED`} or NULL | NULL only for PLOTs |
| `facing` | VARCHAR(20) | NOT NULL, CHECK 8 compass values | All 8 occur, always present |
| `price` | NUMERIC(12,2) | NOT NULL, CHECK > 0 | Monthly rent for RENT, sale price for SALE (7,900 – 99,470,000) |
| `maintenance_monthly` | NUMERIC(10,2) | CHECK > 0 or NULL, CHECK NULL unless project_id present | Charged only inside projects; NULL exactly when `project_id` is NULL (54,009 rows, 0 mismatches) |
| `security_deposit` | NUMERIC(12,2) | CHECK > 0 or NULL, CHECK NULL for SALE | Deposits are rental-only: every RENT row has one, no SALE row does |
| `available_from` | DATE | NOT NULL | Move-in date |
| `latitude` / `longitude` | NUMERIC(10,7) | NOT NULL, CHECK within India's bounds | Map view (R05) needs coordinates on every row |
| `is_verified` | BOOLEAN | NOT NULL DEFAULT FALSE | Export uses `t`/`f`; W01-style inserts omit it, so DEFAULT FALSE |
| `status` | VARCHAR(20) | NOT NULL, CHECK {`ACTIVE`, `INACTIVE`, `RENTED`, `SOLD`} + terminal-status rule | `RENTED` only on RENT, `SOLD` only on SALE (0 violations) |
| `posted_at` | TIMESTAMPTZ | NOT NULL | Listing creation; drives R14/R17/R20/W04 |

### price_changes
| Column | Type | Constraint | Why |
|---|---|---|---|
| `change_id` | INT | PK | Surrogate key |
| `property_id` | INT | NOT NULL, FK → properties (CASCADE) | History follows its listing |
| `old_price` / `new_price` | NUMERIC(12,2) | NOT NULL, CHECK > 0 | Exact money |
| `changed_at` | TIMESTAMPTZ | NOT NULL | Offset preserved |
| — | — | CHECK `new_price <> old_price` | A change that changes nothing is a data error (0 violations) |

### enquiries
| Column | Type | Constraint | Why |
|---|---|---|---|
| `enquiry_id` | INT | PK | Surrogate key |
| `property_id` | INT | NOT NULL, FK → properties (CASCADE) | Lead about a listing |
| `user_id` | INT | NOT NULL, FK → users (CASCADE) | Lead from a seeker |
| `channel` | VARCHAR(20) | NOT NULL, CHECK {`CALL`, `FORM`, `WHATSAPP`} | Three acquisition channels |
| `message` | TEXT | nullable | 50,057 rows have no message (a phone tap needs no text) |
| `created_at` | TIMESTAMPTZ | NOT NULL | Lead timestamp |

### site_visits
| Column | Type | Constraint | Why |
|---|---|---|---|
| `visit_id` | INT | PK | Surrogate key |
| `property_id` / `user_id` | INT | NOT NULL, FKs (CASCADE) | A visit books a seeker into a listing |
| `scheduled_at` | TIMESTAMPTZ | NOT NULL | Visit slot |
| `status` | VARCHAR(20) | NOT NULL, CHECK {`SCHEDULED`, `COMPLETED`, `CANCELLED`, `NO_SHOW`} | Visit lifecycle |
| `feedback_rating` | SMALLINT | CHECK 1–5 or NULL, **CHECK NULL unless status = COMPLETED** | Ratings exist only after a completed visit (14,694 rated rows, all COMPLETED; W03 inserts a SCHEDULED visit with no rating) |

### shortlists
| Column | Type | Constraint | Why |
|---|---|---|---|
| `(user_id, property_id)` | INT, INT | composite PK, both FKs (CASCADE) | A seeker saves a listing once; bridge of the M:N "saved" relation |
| `added_at` | TIMESTAMPTZ | NOT NULL | When it was saved |

## 3. CHECK constraints (the ≥ 12 required)

| # | Constraint (table) | Rule |
|---|---|---|
| 1 | `localities` | pincode matches `^[0-9]{6}$` |
| 2 | `builders` | founded_year between 1800 and 2026 |
| 3 | `projects` | possession_status ∈ {READY_TO_MOVE, UNDER_CONSTRUCTION} |
| 4 | `projects` | rera_id NULL or matches `^[A-Z]{2}-RERA-PR-[0-9]{8}$` |
| 5 | `projects` | total_units > 0 |
| 6 | `users` | phone matches `^[0-9]{10}$` |
| 7 | `users` | email NULL or matches an address pattern |
| 8 | `users` | agent_rera_id NULL or matches `^AG-RERA-[0-9]{8}$` |
| 9 | `users` | user_type ∈ {SEEKER, OWNER, AGENT} |
| 10 | `users` | agent_rera_id is NULL unless user_type = AGENT |
| 11 | `properties` | listing_type ∈ {RENT, SALE} |
| 12 | `properties` | property_type ∈ {APARTMENT, INDEPENDENT_HOUSE, PLOT, VILLA} |
| 13 | `properties` | bhk between 1 and 5 (or NULL) |
| 14 | `properties` | carpet_area_sqft > 0; price > 0 |
| 15 | `properties` | floor_no between 0 and total_floors (or NULL) |
| 16 | `properties` | furnishing ∈ {UNFURNISHED, SEMI_FURNISHED, FULLY_FURNISHED} (or NULL) |
| 17 | `properties` | facing ∈ 8 compass directions |
| 18 | `properties` | security_deposit NULL on SALE listings (rental-only concept) |
| 19 | `properties` | status ∈ {ACTIVE, INACTIVE, RENTED, SOLD} |
| 20 | `properties` | RENTED only on RENT; SOLD only on SALE |
| 21 | `properties` | plots carry no bhk / furnishing / floor_no |
| 22 | `properties` | maintenance_monthly only when project_id is present |
| 23 | `price_changes` | new_price ≠ old_price, both > 0 |
| 24 | `enquiries` | channel ∈ {CALL, FORM, WHATSAPP} |
| 25 | `site_visits` | status ∈ {SCHEDULED, COMPLETED, CANCELLED, NO_SHOW} |
| 26 | `site_visits` | feedback_rating 1–5 and only on COMPLETED visits |
| 27 | `localities` / `properties` | coordinates within India's lat/lng bounds |

## 4. Functional dependencies and normal form

Every table is in **3NF — and in BCNF** except where a *justified* denormalization is
kept (explained per case). For each table: the candidate keys below are verified
against the data (0 duplicates), every non-key attribute depends on the whole key and
on nothing but the key.

| Table | Candidate keys | FDs from the key (non-trivial) | Verdict |
|---|---|---|---|
| `cities` | `city_id`; `city_name` | `city_id → city_name, state` | BCNF |
| `localities` | `locality_id`; `(city_id, locality_name)` | `locality_id → city_id, locality_name, pincode, center_lat, center_lng` | BCNF |
| `builders` | `builder_id`; `builder_name` | `builder_id → builder_name, founded_year` | BCNF |
| `projects` | `project_id`; `rera_id` (NULLable) | `project_id → builder_id, locality_id, project_name, rera_id, possession_status, possession_date, total_units` | BCNF |
| `amenities` | `amenity_id`; `amenity_name` | `amenity_id → amenity_name` | BCNF |
| `project_amenities` | `(project_id, amenity_id)` | none beyond the key | BCNF (all-key) |
| `users` | `user_id`; `phone`; `email`; `agent_rera_id` | `user_id → full_name, phone, email, user_type, agent_rera_id, created_at` | BCNF |
| `properties` | `property_id` | `property_id → listed_by, project_id, locality_id, …, posted_at` | BCNF with one deliberate redundancy, below |
| `price_changes` | `change_id` | `change_id → property_id, old_price, new_price, changed_at` | BCNF |
| `enquiries` | `enquiry_id` | `enquiry_id → property_id, user_id, channel, message, created_at` | BCNF |
| `site_visits` | `visit_id` | `visit_id → property_id, user_id, scheduled_at, status, feedback_rating` | BCNF |
| `shortlists` | `(user_id, property_id)` | → `added_at` | BCNF (all-key) |

**Derived / redundant columns — keep or drop? (the brief's hint, answered):**

- *price per sq ft* — **not stored**, always computed in queries (R02, R04, R15:
  `price / carpet_area_sqft`). Storing it would violate 3NF (functionally dependent on
  two stored columns) and go stale on every price change. Correct call: compute it.
- *`properties.price` vs the latest `price_changes.new_price`* — the current price IS
  duplicated in `price_changes` (the newest row of each property's history repeats
  it; verified: **all 23,425 latest new_price values equal `properties.price`**). We
  keep both: `properties.price` is what every search page filters and sorts on, and
  forcing a `max(changed_at)` subquery per row would make R01/R02-style queries
  dramatically slower. The redundancy is write-time-checked by integrity check IC-2
  (§6) rather than a trigger, which would complicate the Phase 3 baseline.
- *`properties.locality_id` vs its project's locality* — denormalized on purpose for
  standalone listings (no project to join) and for search filters that must not pay a
  `projects` join on every scan. The consistency rule "property locality = project
  locality" holds for **all 66,051 project-backed listings** (IC-1, §6). In 3NF terms
  this is a *conditional* transitive dependency (`project_id → locality_id` only
  applies when project_id is non-NULL); we keep it as a documented, check-enforced
  denormalization, the standard trade for read-heavy workloads.
- *`maintenance_monthly` ⇔ project membership* — not an FD issue but a conditional
  rule; captured as CHECK #22.

## 5. ER diagram

Crow's-foot diagram with all 12 tables, keys and 15 relationships:
[`diagrams/er_diagram.svg`](../diagrams/er_diagram.svg).

Relationship summary:

| Relationship | Cardinality | Notes |
|---|---|---|
| cities → localities | 1 : N | RESTRICT on delete |
| localities → projects | 1 : N | RESTRICT |
| builders → projects | 1 : N | RESTRICT |
| localities → properties | 1 : N | RESTRICT |
| projects → properties | 0..1 : N | nullable `project_id` (SET NULL) — standalone listings exist |
| projects ↔ amenities | M : N | via `project_amenities` bridge |
| users → properties | 1 : N | `listed_by`, only OWNER/AGENT (IC-3) |
| users → enquiries / site_visits / shortlists | 1 : N | activity side, CASCADE |
| properties → price_changes / enquiries / site_visits / shortlists | 1 : N | CASCADE |
| users ↔ properties | M : N | via `shortlists` bridge |

## 6. Integrity checks (run on the loaded database)

PostgreSQL 16, loaded via `sql/02_load_data.sql`. All 12 row counts matched the CSVs
exactly, then we ran the checks the brief asks for (each returns the number of
violations):

```sql
-- IC-1: a property inside a project is in the project's locality
SELECT count(*) FROM properties p JOIN projects pj ON pj.project_id = p.project_id
 WHERE p.locality_id <> pj.locality_id;                      -- 0

-- IC-2: the current price equals the latest price change
SELECT count(*) FROM properties p JOIN price_changes c ON c.property_id = p.property_id
 WHERE c.changed_at = (SELECT max(c2.changed_at) FROM price_changes c2
                        WHERE c2.property_id = p.property_id)
   AND p.price <> c.new_price;                                -- 0

-- IC-3: only owners and agents list properties
SELECT count(*) FROM properties p JOIN users u ON u.user_id = p.listed_by
 WHERE u.user_type NOT IN ('OWNER','AGENT');                  -- 0
```

Additional checks we ran (all **0 violations**): deposits only on rentals; ratings
only on completed visits; plots carry no BHK/furnishing/floor; floor ≤ total_floors;
RENTED-on-RENT and SOLD-on-SALE; non-agents carry no agent RERA id; maintenance only
with a project; every RERA id matches `XX-RERA-PR-########`; every latest
`price_changes.new_price` equals `properties.price`. **All 30 workload queries
(R01–R25 reads + W01–W05 writes) also executed unmodified against this schema.**

## 7. Data problems found

1. **R13 is logically wrong, not the data.** "Projects with no property listed" uses
   `NOT IN (SELECT project_id FROM properties)`, but `project_id` is NULL on 54,009
   standalone listings — one NULL in the subquery makes `NOT IN` return **zero rows**,
   though **120 of 1,200 projects genuinely have no listings** (seed data: 1,080
   projects are referenced). This is the brief's NULL-trap query; we benchmark it
   unmodified in Phase 3 and fix it with `NOT EXISTS` in Phase 4.
2. **171 projects (14.25%) have no RERA id.** Registration is legally required for new
   projects; these are legacy or export gaps. We allow NULL in `rera_id` (R10-style
   lookups simply won't match them) and flag it as a business-side data-quality issue.
3. **15,990 of 40,000 users (40%) have no email**, and 50,057 of 100,000 enquiries
   (50%) have no message. Not corruption — phone-channel activity simply leaves them
   empty; both columns stay nullable.
4. **`maintenance_monthly` is NULL on exactly the 54,009 standalone listings** and
   present on all 66,051 project-backed ones — a perfect correlation, so we encoded it
   as CHECK #22 rather than treating NULLs as missing data.
5. **Duplicates that are legal:** the same flat description (locality, area, floor,
   BHK) listed repeatedly by the same lister is R18's fraud signal — the data
   contains such groups, so we must *not* over-constrain `properties` with a natural
   UNIQUE key that would forbid them.
6. **Under-construction projects with past possession dates exist** (R24 finds them
   — 120+ rows). Rather than reject them (they're the buyer-protection report's
   whole input), we allow `possession_date` in the past and only CHECK that
   READY_TO_MOVE projects are not dated in the future.

## 8. Indexes that exist after Phase 2 (no tuning yet)

Per the rules, we created **no** secondary indexes. PostgreSQL's implicit indexes
from PK/UNIQUE constraints are the entire index set: 20 unique b-trees — each
table's `*_pkey`, plus `cities_city_name_key`, `localities_city_id_locality_name_key`,
`builders_builder_name_key`, `projects_rera_id_key`, `amenities_amenity_name_key`,
`users_phone_key`, `users_email_key`, `users_agent_rera_id_key`. Everything else
(locality filters, price ranges, join keys like `properties.listed_by`, timestamps)
will be sequential scans in Phase 3 — the intended untuned baseline.

Table sizes after load (total, incl. indexes): `properties` 25 MB, `enquiries`
9,480 kB, `users` 8,032 kB, `shortlists` 4,616 kB, `site_visits` 3,128 kB,
`price_changes` 2,096 kB; the reference tables are ≤ 448 kB.
