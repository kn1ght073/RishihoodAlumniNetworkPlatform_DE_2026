-- =====================================================================
-- Housing.com DBMS Project — Phase 5: Table Partitioning DDL & Analysis
-- Team T0079 · Checkpoint 4 (CP4) · PostgreSQL 15+
--
-- File: sql/08_partitioning.sql
-- Description:
--   Declarative table partitioning implementation for the largest table
--   in Housing.com (housing.properties, containing 2.4M+ rows at 20x scale,
--   projected to reach 12M+ rows at 100x scale).
--
-- Architectural Decisions:
--   1. Partitioning Strategy: RANGE Partitioning on `posted_at`.
--      - Justification: Property listings have a distinct lifecycle. 
--        Active searches, price-trend analyses (R04), date-bucketed metrics (R20),
--        and stale listing cleanups (W04) filter heavily on `posted_at`.
--        Furthermore, historical / deactivated listings (> 1-2 years old)
--        can be archived, compressed, or routed to cold storage without
--        impacting live transactional tables.
--   2. PostgreSQL Primary Key Rule for Partitioned Tables:
--      - In PostgreSQL declarative partitioning, any UNIQUE or PRIMARY KEY
--        constraint on the partitioned table MUST include the partition key.
--        Therefore, the composite key `(property_id, posted_at)` is required.
--   3. Partition Pruning:
--      - Demonstrates static and dynamic partition pruning (`enable_partition_pruning = on`),
--        ensuring queries touching specific quarters scan ONLY the relevant
--        child partition, reducing I/O buffer reads and query latency.
-- =====================================================================

SET search_path TO housing;

-- ---------------------------------------------------------------------
-- 1. Create Partitioned Properties Table (RANGE on posted_at)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS housing.properties_partitioned CASCADE;

CREATE TABLE housing.properties_partitioned (
    property_id         INT             NOT NULL,
    listed_by           INT             NOT NULL REFERENCES housing.users(user_id) ON DELETE RESTRICT,
    project_id          INT             REFERENCES housing.projects(project_id) ON DELETE RESTRICT,
    locality_id         INT             NOT NULL REFERENCES housing.localities(locality_id) ON DELETE RESTRICT,
    listing_type        VARCHAR(10)     NOT NULL CHECK (listing_type IN ('RENT', 'SALE')),
    property_type       VARCHAR(20)     NOT NULL CHECK (property_type IN ('APARTMENT', 'INDEPENDENT_HOUSE', 'VILLA', 'PLOT')),
    bhk                 INT             CHECK (bhk IS NULL OR (bhk BETWEEN 1 AND 10)),
    carpet_area_sqft    NUMERIC(10,2)   NOT NULL CHECK (carpet_area_sqft > 0),
    floor_no            INT,
    total_floors        INT,
    furnishing          VARCHAR(20)     CHECK (furnishing IS NULL OR furnishing IN ('UNFURNISHED', 'SEMI_FURNISHED', 'FULLY_FURNISHED')),
    facing              VARCHAR(15)     CHECK (facing IS NULL OR facing IN ('NORTH', 'SOUTH', 'EAST', 'WEST', 'NORTH_EAST', 'NORTH_WEST', 'SOUTH_EAST', 'SOUTH_WEST')),
    price               NUMERIC(14,2)   NOT NULL CHECK (price > 0),
    maintenance_monthly NUMERIC(10,2)   CHECK (maintenance_monthly IS NULL OR maintenance_monthly >= 0),
    security_deposit    NUMERIC(14,2)   CHECK (security_deposit IS NULL OR security_deposit >= 0),
    available_from      DATE            NOT NULL,
    latitude            NUMERIC(10,7),
    longitude           NUMERIC(10,7),
    is_verified         BOOLEAN         NOT NULL DEFAULT FALSE,
    status              VARCHAR(15)     NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'RENTED', 'SOLD', 'DEACTIVATED')),
    posted_at           TIMESTAMPTZ     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Mandatory PostgreSQL Partitioning Rule:
    -- Primary key MUST include the partition key column (posted_at)
    CONSTRAINT pk_properties_partitioned PRIMARY KEY (property_id, posted_at),
    CONSTRAINT chk_part_floors CHECK (floor_no IS NULL OR total_floors IS NULL OR floor_no <= total_floors)
) PARTITION BY RANGE (posted_at);

-- ---------------------------------------------------------------------
-- 2. Define Partitions (Quarterly & Annual Ranges for Workload)
-- ---------------------------------------------------------------------

-- Historical partition: All listings posted before 2026
CREATE TABLE housing.properties_pre_2026 PARTITION OF housing.properties_partitioned
    FOR VALUES FROM (MINVALUE) TO ('2026-01-01 00:00:00+00');

-- 2026 Q1: Jan 1, 2026 to Apr 1, 2026
CREATE TABLE housing.properties_2026_q1 PARTITION OF housing.properties_partitioned
    FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2026-04-01 00:00:00+00');

-- 2026 Q2: Apr 1, 2026 to Jul 1, 2026
CREATE TABLE housing.properties_2026_q2 PARTITION OF housing.properties_partitioned
    FOR VALUES FROM ('2026-04-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');

-- 2026 Q3: Jul 1, 2026 to Oct 1, 2026
CREATE TABLE housing.properties_2026_q3 PARTITION OF housing.properties_partitioned
    FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-10-01 00:00:00+00');

-- 2026 Q4 & Future: Oct 1, 2026 to Upper Limit
CREATE TABLE housing.properties_2026_q4_future PARTITION OF housing.properties_partitioned
    FOR VALUES FROM ('2026-10-01 00:00:00+00') TO (MAXVALUE);


-- ---------------------------------------------------------------------
-- 3. Local Partition Indexes (Mirrored from 05_indexes.sql)
--    PostgreSQL automatically propagates table-level indexes to all partitions!
-- ---------------------------------------------------------------------

CREATE INDEX ix_part_rent_search
    ON housing.properties_partitioned (locality_id, bhk, price)
    INCLUDE (property_id, carpet_area_sqft, furnishing, available_from)
    WHERE listing_type = 'RENT' AND status = 'ACTIVE';

CREATE INDEX ix_part_sale_search
    ON housing.properties_partitioned (locality_id, bhk, price)
    INCLUDE (property_id, carpet_area_sqft)
    WHERE listing_type = 'SALE' AND status = 'ACTIVE' AND property_type = 'APARTMENT';

CREATE INDEX ix_part_sale_trend
    ON housing.properties_partitioned (locality_id, posted_at)
    INCLUDE (price, carpet_area_sqft)
    WHERE listing_type = 'SALE' AND property_type = 'APARTMENT';

CREATE INDEX ix_part_map_rent
    ON housing.properties_partitioned (latitude, longitude)
    INCLUDE (property_id, price, bhk)
    WHERE listing_type = 'RENT' AND status = 'ACTIVE';

CREATE INDEX ix_part_lister
    ON housing.properties_partitioned (listed_by, property_id)
    INCLUDE (listing_type, status, price);

CREATE INDEX ix_part_project_active
    ON housing.properties_partitioned (project_id, status)
    INCLUDE (bhk, listing_type, price)
    WHERE project_id IS NOT NULL;

CREATE INDEX ix_part_active_posted
    ON housing.properties_partitioned (posted_at)
    INCLUDE (property_id, listed_by, listing_type, price)
    WHERE status = 'ACTIVE';


-- ---------------------------------------------------------------------
-- 4. Sample Migration DML: Populate Partitioned Table from Main Table
-- ---------------------------------------------------------------------
-- INSERT INTO housing.properties_partitioned
-- SELECT * FROM housing.properties;
-- ANALYZE housing.properties_partitioned;


-- ---------------------------------------------------------------------
-- 5. Demonstration of Partition Pruning with EXPLAIN
-- ---------------------------------------------------------------------

-- Verification Query 1: Single Quarter Lookup (2026 Q2)
-- The query planner prunes pre_2026, 2026_q1, 2026_q3, and 2026_q4.
-- Plan inspection will show scanning ONLY properties_2026_q2!
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*), avg(price)
FROM housing.properties_partitioned
WHERE posted_at >= '2026-05-01 00:00:00+00' 
  AND posted_at < '2026-06-01 00:00:00+00'
  AND status = 'ACTIVE';

-- Verification Query 2: Trend Analysis Pruning (R04-style)
-- Restricted to 2026 listings; pre-2026 is completely pruned.
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_trunc('month', posted_at) AS month, count(*), avg(price / carpet_area_sqft)
FROM housing.properties_partitioned
WHERE locality_id = 1
  AND listing_type = 'SALE'
  AND property_type = 'APARTMENT'
  AND posted_at >= '2026-01-01 00:00:00+00' 
  AND posted_at < '2027-01-01 00:00:00+00'
GROUP BY 1 ORDER BY 1;
