-- =====================================================================
-- Housing.com Property Search Database — Phase 2 deliverable
-- Team T0079 · CP1 · PostgreSQL 15+
--
-- Run top-to-bottom on an EMPTY database:
--   psql -d <your_database> -f sql/01_schema.sql
--
-- Rules honoured (README §2.2):
--   * every table lives in schema "housing"
--   * constraints ONLY (PK / FK / UNIQUE / NOT NULL / CHECK)
--     — no extra indexes; PG auto-creates PK/UNIQUE indexes, noted in
--       docs/02_schema_design.md
--   * every constraint accepts ALL rows of the seed data (verified by
--     loading the 12 CSVs; see docs/02_schema_design.md §6)
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS housing;
SET search_path TO housing;

-- ---------------------------------------------------------------------
-- 1. cities  (10 rows)
-- ---------------------------------------------------------------------
CREATE TABLE housing.cities (
    city_id   INT          PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL UNIQUE,
    state     VARCHAR(100) NOT NULL
);

-- ---------------------------------------------------------------------
-- 2. localities  (100 rows)
-- ---------------------------------------------------------------------
CREATE TABLE housing.localities (
    locality_id   INT           PRIMARY KEY,
    city_id       INT           NOT NULL REFERENCES housing.cities(city_id) ON DELETE RESTRICT,
    locality_name VARCHAR(150)  NOT NULL,
    pincode       VARCHAR(10)   NOT NULL CHECK (pincode ~ '^[0-9]{6}$'),
    center_lat    NUMERIC(10,7),
    center_lng    NUMERIC(10,7),
    UNIQUE (city_id, locality_name)          -- no two localities share a name inside a city
);

-- ---------------------------------------------------------------------
-- 3. builders  (150 rows)
-- ---------------------------------------------------------------------
CREATE TABLE housing.builders (
    builder_id   INT          PRIMARY KEY,
    builder_name VARCHAR(150) NOT NULL UNIQUE,
    founded_year INT          CHECK (founded_year IS NULL OR founded_year BETWEEN 1800 AND 2026)
);

-- ---------------------------------------------------------------------
-- 4. projects  (1,200 rows)
--    RERA ids look like MH-RERA-PR-10007919; 171 rows have no RERA id
--    (unregistered / legacy projects) — UNIQUE allows multiple NULLs.
-- ---------------------------------------------------------------------
CREATE TABLE housing.projects (
    project_id         INT          PRIMARY KEY,
    builder_id         INT          NOT NULL REFERENCES housing.builders(builder_id) ON DELETE RESTRICT,
    locality_id        INT          NOT NULL REFERENCES housing.localities(locality_id) ON DELETE RESTRICT,
    project_name       VARCHAR(200) NOT NULL,
    rera_id            VARCHAR(100) UNIQUE
                       CHECK (rera_id IS NULL OR rera_id ~ '^[A-Z]{2}-RERA-PR-[0-9]{8}$'),
    possession_status  VARCHAR(50)  NOT NULL
                       CHECK (possession_status IN ('READY_TO_MOVE', 'UNDER_CONSTRUCTION')),
    possession_date    DATE         NOT NULL,
    total_units        INT          NOT NULL CHECK (total_units > 0),
    CHECK (possession_status <> 'READY_TO_MOVE' OR possession_date <= CURRENT_DATE)
    -- a project claimed READY before today is fine; an UNDER_CONSTRUCTION project
    -- with a possession_date in the past is flagged by R24 instead of rejected,
    -- because the seed data contains such rows deliberately.
);

-- ---------------------------------------------------------------------
-- 5. amenities  (15 rows)
-- ---------------------------------------------------------------------
CREATE TABLE housing.amenities (
    amenity_id   INT          PRIMARY KEY,
    amenity_name VARCHAR(100) NOT NULL UNIQUE
);

-- ---------------------------------------------------------------------
-- 6. project_amenities  (6,806 rows) — M:N bridge, composite PK
-- ---------------------------------------------------------------------
CREATE TABLE housing.project_amenities (
    project_id INT NOT NULL REFERENCES housing.projects(project_id)  ON DELETE CASCADE,
    amenity_id INT NOT NULL REFERENCES housing.amenities(amenity_id) ON DELETE CASCADE,
    PRIMARY KEY (project_id, amenity_id)
);

-- ---------------------------------------------------------------------
-- 7. users  (40,000 rows)
--    Only AGENTs have an agent_rera_id; every agent has one.
--    Phone is the sign-in key (R23) — unique and required.
--    Email is optional and unique when present.
-- ---------------------------------------------------------------------
CREATE TABLE housing.users (
    user_id        INT          PRIMARY KEY,
    full_name      VARCHAR(150) NOT NULL,
    phone          VARCHAR(20)  NOT NULL UNIQUE CHECK (phone ~ '^[0-9]{10}$'),
    email          VARCHAR(255) UNIQUE CHECK (email IS NULL OR email ~ '^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$'),
    user_type      VARCHAR(30)  NOT NULL CHECK (user_type IN ('SEEKER', 'OWNER', 'AGENT')),
    agent_rera_id  VARCHAR(100) UNIQUE
                   CHECK (agent_rera_id IS NULL OR agent_rera_id ~ '^AG-RERA-[0-9]{8}$')
                   CHECK (user_type = 'AGENT' OR agent_rera_id IS NULL),
                   -- non-agents must not carry a RERA id (seed data: 0 violations)
    created_at     TIMESTAMPTZ  NOT NULL
);

-- ---------------------------------------------------------------------
-- 8. properties  (120,060 rows)
--    project_id NULL   → standalone house / villa / plot (54,009 rows)
--    maintenance_monthly NULL  ⇔  project_id NULL (verified on seed data)
--    bhk, furnishing, total_floors NULL → PLOTs only
--    floor_no NULL     → standalone houses / villas / plots
--    security_deposit  → rentals only, always present on RENT rows
--    status: RENTED only on RENT listings, SOLD only on SALE listings
-- ---------------------------------------------------------------------
CREATE TABLE housing.properties (
    property_id        INT           PRIMARY KEY,
    listed_by          INT           NOT NULL REFERENCES housing.users(user_id) ON DELETE RESTRICT,
    project_id         INT           REFERENCES housing.projects(project_id) ON DELETE SET NULL,
    locality_id        INT           NOT NULL REFERENCES housing.localities(locality_id) ON DELETE RESTRICT,
    listing_type       VARCHAR(30)   NOT NULL CHECK (listing_type IN ('RENT', 'SALE')),
    property_type      VARCHAR(50)   NOT NULL
                       CHECK (property_type IN ('APARTMENT', 'INDEPENDENT_HOUSE', 'PLOT', 'VILLA')),
    bhk                INT           CHECK (bhk IS NULL OR bhk BETWEEN 1 AND 5),
    carpet_area_sqft   NUMERIC(10,2) NOT NULL CHECK (carpet_area_sqft > 0),
    floor_no           INT           CHECK (floor_no IS NULL OR (floor_no >= 0 AND floor_no <= total_floors)),
    total_floors       INT           CHECK (total_floors IS NULL OR total_floors > 0),
    furnishing         VARCHAR(30)   CHECK (furnishing IS NULL OR
                           furnishing IN ('UNFURNISHED', 'SEMI_FURNISHED', 'FULLY_FURNISHED')),
    facing             VARCHAR(20)   NOT NULL CHECK (facing IN
                       ('NORTH', 'NORTH_EAST', 'EAST', 'SOUTH_EAST', 'SOUTH',
                        'SOUTH_WEST', 'WEST', 'NORTH_WEST')),
    price              NUMERIC(12,2) NOT NULL CHECK (price > 0),
    maintenance_monthly NUMERIC(10,2) CHECK (maintenance_monthly IS NULL OR maintenance_monthly > 0),
    security_deposit   NUMERIC(12,2) CHECK (security_deposit IS NULL OR security_deposit > 0),
    available_from     DATE          NOT NULL,
    latitude           NUMERIC(10,7) NOT NULL CHECK (latitude  BETWEEN   8.0 AND   35.5),  -- India bounds
    longitude          NUMERIC(10,7) NOT NULL CHECK (longitude BETWEEN  68.0 AND   97.5),
    is_verified        BOOLEAN       NOT NULL DEFAULT FALSE,
    status             VARCHAR(20)   NOT NULL
                       CHECK (status IN ('ACTIVE', 'INACTIVE', 'RENTED', 'SOLD')),
    posted_at          TIMESTAMPTZ   NOT NULL,
    -- plots never carry BHK / furnishing / floor data (seed data: 0 violations)
    CHECK (property_type <> 'PLOT' OR (bhk IS NULL AND furnishing IS NULL AND floor_no IS NULL)),
    -- a floor number only makes sense inside a building (seed data: 0 violations)
    CHECK (floor_no IS NULL OR total_floors IS NOT NULL),
    -- deposits are a rental concept; SALE rows must leave them NULL (seed: 0 violations)
    CHECK (listing_type = 'RENT' OR security_deposit IS NULL),
    -- terminal statuses belong to their listing type (seed: 0 violations)
    CHECK (status NOT IN ('RENTED', 'SOLD')
           OR (status = 'RENTED' AND listing_type = 'RENT')
           OR (status = 'SOLD'   AND listing_type = 'SALE')),
    -- maintenance is charged only on project units (seed: mm NULL ⇔ project NULL)
    CHECK (maintenance_monthly IS NULL OR project_id IS NOT NULL)
);

-- ---------------------------------------------------------------------
-- 9. price_changes  (23,425 rows)
--    Every property's CURRENT price equals its latest new_price
--    (verified on seed data — see docs §6 check IC-2).
-- ---------------------------------------------------------------------
CREATE TABLE housing.price_changes (
    change_id   INT           PRIMARY KEY,
    property_id INT           NOT NULL REFERENCES housing.properties(property_id) ON DELETE CASCADE,
    old_price   NUMERIC(12,2) NOT NULL CHECK (old_price > 0),
    new_price   NUMERIC(12,2) NOT NULL CHECK (new_price > 0),
    changed_at  TIMESTAMPTZ   NOT NULL,
    CHECK (new_price <> old_price)                 -- a "change" must change something
);

-- ---------------------------------------------------------------------
-- 10. enquiries  (100,000 rows)
--     message optional (50,057 empty in seed), channel from CALL/FORM/WHATSAPP
-- ---------------------------------------------------------------------
CREATE TABLE housing.enquiries (
    enquiry_id  INT          PRIMARY KEY,
    property_id INT          NOT NULL REFERENCES housing.properties(property_id) ON DELETE CASCADE,
    user_id     INT          NOT NULL REFERENCES housing.users(user_id)      ON DELETE CASCADE,
    channel     VARCHAR(20)  NOT NULL CHECK (channel IN ('CALL', 'FORM', 'WHATSAPP')),
    message     TEXT,
    created_at  TIMESTAMPTZ  NOT NULL
);

-- ---------------------------------------------------------------------
-- 11. site_visits  (35,120 rows)
--     feedback_rating 2–5, only allowed once the visit is COMPLETED
--     (seed data: ratings appear ONLY on COMPLETED rows — 0 violations)
-- ---------------------------------------------------------------------
CREATE TABLE housing.site_visits (
    visit_id        INT         PRIMARY KEY,
    property_id     INT         NOT NULL REFERENCES housing.properties(property_id) ON DELETE CASCADE,
    user_id         INT         NOT NULL REFERENCES housing.users(user_id)      ON DELETE CASCADE,
    scheduled_at    TIMESTAMPTZ NOT NULL,
    status          VARCHAR(20) NOT NULL
                    CHECK (status IN ('SCHEDULED', 'COMPLETED', 'CANCELLED', 'NO_SHOW')),
    feedback_rating SMALLINT    CHECK (feedback_rating IS NULL OR feedback_rating BETWEEN 1 AND 5),
    CHECK (feedback_rating IS NULL OR status = 'COMPLETED')
);

-- ---------------------------------------------------------------------
-- 12. shortlists  (69,999 rows) — composite PK (user, property)
-- ---------------------------------------------------------------------
CREATE TABLE housing.shortlists (
    user_id     INT         NOT NULL REFERENCES housing.users(user_id)      ON DELETE CASCADE,
    property_id INT         NOT NULL REFERENCES housing.properties(property_id) ON DELETE CASCADE,
    added_at    TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (user_id, property_id)
);

-- ---------------------------------------------------------------------
-- Automatic indexes created by PostgreSQL (schema-only phase, no tuning):
--   PK  → housing.<table>_pkey              (unique btree on the PK column(s))
--   UNIQUE → housing.users_phone_key, housing.users_email_key,
--            housing.users_agent_rera_id_key, housing.projects_rera_id_key,
--            housing.cities_city_name_key, housing.builders_builder_name_key,
--            housing.amenities_amenity_name_key,
--            housing.localities_city_id_locality_name_key
-- Everything else (filtering, joining, sorting) runs as sequential scans —
-- that is the intentional Phase 3 baseline. Index design starts in Phase 4.
-- ---------------------------------------------------------------------
