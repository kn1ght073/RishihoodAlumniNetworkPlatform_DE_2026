# Problem Understanding

**Project:** Housing.com Property Search Database · **Team T0079** · **Phase 1**

We reviewed the seven problem statements from the project brief against the seed data
(12 CSV exports, 120,060 property listings) and classified each one. The classification
drives our performance targets in Phase 5: customer-facing / real-time problems get the
tightest targets (under 5 ms on the large dataset), reporting / analytics problems get
looser ones (under 5,000 ms).

---

## P1: Slow rent and buy searches

- **Business need:** Home seekers must be able to filter rentals and sale listings by
  price, price per sq ft, locality, BHK, furnishing and amenities, and get results
  quickly. A search page that takes seconds loses users to competitors. Today every
  filter combination runs as a full scan of the 120,060-row `properties` table because
  the export has no secondary indexes at all — only the implicit PK/UNIQUE ones.
- **Stakeholders:** Home seekers (tenants and buyers) — the platform's largest user
  group; the Search team who own the search product.
- **Related queries:** R01 (rent search with locality + BHK + price + furnishing
  filters), R02 (buy search ordered by price per sq ft), R05 (map view: rentals inside
  a bounding box on latitude/longitude), R09 (amenity filter: projects with gym AND
  swimming pool AND power backup), R16 (search box, project name ILIKE).
- **Category:** **Customer-facing / real-time.** Filters run on every search request,
  hundreds of times per minute.

## P2: Slow property and project pages

- **Business need:** The detail page of a listing (and of the project it belongs to)
  must load instantly, including the RERA registration details buyers use for due
  diligence before spending crores. A listing page that lags makes the platform feel
  untrustworthy.
- **Stakeholders:** Home seekers; owners and agents who want their listings viewed;
  builders whose projects are showcased; the Listings team.
- **Related queries:** R03 (property 6897 joined to its project, builder and amenity
  list), R10 (project lookup by exact RERA id), R11 (available listings in a project
  grouped by BHK), R24 (buyer protection: under-construction projects whose possession
  date has passed).
- **Category:** **Customer-facing / real-time.**

## P3: Slow owner and agent dashboards

- **Business need:** Owners and agents manage their listings from a dashboard: they
  check enquiries and site-visit counts per listing, see tomorrow's visit schedule,
  change prices and update statuses. Slow dashboards mean agents cannot respond to
  leads while they are on the phone with a customer.
- **Stakeholders:** Property owners, agents, and the Listings team.
- **Related queries:** R06 (owner 1033's listings with enquiry and visit counts),
  R07 (visits scheduled on 1 July 2026 for one agent's properties), W01 (post a
  property), W02 (5% price cut), W03 (book a site visit), W05 (mark a rental as rented).
- **Category:** **Customer-facing / real-time.** Note the write queries: our Phase 4
  indexes must not slow writes so much that posting or updating a listing becomes
  sluggish.

## P4: Delayed alerts and follow-ups

- **Business need:** The Engagement team runs hourly jobs: notify seekers when an
  active listing's price drops by 10%+, nudge owners about leads that never booked a
  site visit, and remind owners of listings that have been active for 90+ days with no
  enquiries at all. If these jobs are slow they cannot complete within their hourly
  window as data grows 20×.
- **Stakeholders:** Home seekers (price-drop alerts), owners (nudges, lead follow-up),
  agents, and the Engagement team.
- **Related queries:** R08 (price drops of 10%+ in June 2026), R12 (June enquiries with
  no site visit by that user), R17 (active listings older than 90 days with zero
  enquiries).
- **Category:** **Real-time / background processing** — the results feed user-facing
  alerts, so we treat the queries as interactive (target under 250 ms) even though they
  run as jobs.

## P5: Empty builder-partnerships report

- **Business need:** The Builder Partnerships team looks for projects that have **no
  property listings** on the platform — these are sales leads ("project ready, no
  units listed yet"). The report currently always comes back empty, which we verified
  is a **logic bug, not a performance problem**: the query uses `NOT IN` against
  `properties.project_id`, a nullable column, so a single NULL in the subquery makes
  `NOT IN` return nothing (verified on the seed data: unmodified query returns 0 rows;
  the correct answer is 120 projects). This is exactly the NULL-trap the brief warns
  about; we will document and fix it in Phase 4 with `NOT EXISTS`.
- **Stakeholders:** Builders (they get partnership outreach), and the Builder
  Partnerships team.
- **Related queries:** R13.
- **Category:** **Reporting / analytics**, currently broken. Fixing correctness is a
  prerequisite before its speed matters.

## P6: Timeouts in insights

- **Business need:** Management and investors need price trends, rental yields by
  locality, agent leaderboards, visit ratings per locality and the
  shortlist→enquiry conversion funnel. These aggregate the whole dataset (R19 scans
  every active sale property in Bengaluru with two correlated subqueries per row), so
  they time out today.
- **Stakeholders:** Investors and management (strategy), the Growth team, and the
  Insights team.
- **Related queries:** R04 (monthly price-per-sq-ft trend), R14 (agent leaderboard),
  R15 (rental yield per locality), R19 (city report with latest-enquiry subqueries),
  R20 (new listings per day with running total), R21 (average visit rating per
  locality), R25 (funnel per city).
- **Category:** **Reporting / analytics.** Tolerates seconds, not minutes; candidate
  for covering indexes and (in Phase 5) a summary table.

## P7: Trust & safety, moderation and platform growth

- **Business need:** Fraud detection must find the same flat listed repeatedly by the
  same lister; the moderation console must page through all listings newest-first
  (page 2,001 × 25); sign-in by phone must be instant; and the whole platform must
  survive **20× growth** (≈ 2.4 M listings, ≈ 2 M enquiries) next year.
- **Stakeholders:** The Trust & Safety team, the Platform team, and every user who
  signs in (R23: sign-in by mobile number — a single-user lookup that must never
  queue).
- **Related queries:** R18 (duplicate-listing detection), R19 (city report),
  R22 (deep-pagination console — `OFFSET 50000` must be replaced with keyset
  pagination in Phase 4), R23 (phone sign-in), W04 (nightly job deactivating listings
  older than 120 days).
- **Category:** **Mixed:** R23 and W04 are customer-facing / real-time and batch
  respectively; R18, R19, R22 are reporting / analytics.

---

## Assumptions

1. **Same measurement environment.** Phases 3 and 4 are benchmarked on the same
   laptop (recorded in `team.json`), with `EXPLAIN (ANALYZE, BUFFERS)` and 3 runs per
   query, as the brief requires.
2. **Seed data is a faithful production sample.** Row counts and value distributions
   (10 cities, 100 localities, 40,000 users, 120,060 properties) reflect production
   shapes, so index selectivity measured on it transfers to the 20× dataset.
3. **Price currency is INR.** Rent and deposit values (₹7,900 – ₹99,470,000) are
   Indian rupees; `price` on a RENT listing is monthly rent, consistent with the seed
   data and queries like R01 (price ≤ 40,000/month).
4. **`posted_at` is the listing creation time** used by every age-based rule (R17's
   90-day nudges, W04's 120-day deactivation, R14's "in 2026"), not the time the
   property became available (`available_from`).
5. **Nullability mirrors reality.** A property with no `project_id` is a standalone
   house, villa or plot (54,009 of 120,060 rows); plots never carry BHK, furnishing or
   floor data. `rera_id` is empty for 171 of 1,200 projects (unregistered or legacy),
   and PostgreSQL's UNIQUE correctly allows multiple NULLs there.
6. **The hourly alert jobs (P4) must fit an hourly window** even on the 20× dataset;
   we treat their queries as interactive (under 250 ms) rather than batch.
7. **R13's empty result is a NULL-semantics bug in the given query**, not missing
   data: 120 of 1,200 projects genuinely have no listings. We benchmark the query
   unmodified in Phase 3 and repair it in Phase 4, as the brief instructs.
