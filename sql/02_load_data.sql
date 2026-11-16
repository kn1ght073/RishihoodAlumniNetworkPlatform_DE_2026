-- =====================================================================
-- Housing.com Property Search Database — Phase 2 data load
-- Team T0079 · CP1
--
-- Usage (run from the repository root, after unzipping seed_data.zip):
--   psql -d <your_database> -f sql/02_load_data.sql
--
-- \copy is a psql client-side command: paths are relative to the
-- directory psql was started from (hence seed_data/…). Parents are
-- loaded before children so every FK is satisfied as we go.
-- =====================================================================

SET search_path TO housing;

-- reference data ------------------------------------------------------
\copy housing.cities (city_id, city_name, state) FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true)

\copy housing.localities (locality_id, city_id, locality_name, pincode, center_lat, center_lng) FROM 'seed_data/localities.csv' WITH (FORMAT csv, HEADER true)

\copy housing.builders (builder_id, builder_name, founded_year) FROM 'seed_data/builders.csv' WITH (FORMAT csv, HEADER true)

-- projects depend on builders + localities ----------------------------
\copy housing.projects (project_id, builder_id, locality_id, project_name, rera_id, possession_status, possession_date, total_units) FROM 'seed_data/projects.csv' WITH (FORMAT csv, HEADER true)

\copy housing.amenities (amenity_id, amenity_name) FROM 'seed_data/amenities.csv' WITH (FORMAT csv, HEADER true)

\copy housing.project_amenities (project_id, amenity_id) FROM 'seed_data/project_amenities.csv' WITH (FORMAT csv, HEADER true)

-- users before properties (properties.listed_by → users) --------------
\copy housing.users (user_id, full_name, phone, email, user_type, agent_rera_id, created_at) FROM 'seed_data/users.csv' WITH (FORMAT csv, HEADER true)

\copy housing.properties (property_id, listed_by, project_id, locality_id, listing_type, property_type, bhk, carpet_area_sqft, floor_no, total_floors, furnishing, facing, price, maintenance_monthly, security_deposit, available_from, latitude, longitude, is_verified, status, posted_at) FROM 'seed_data/properties.csv' WITH (FORMAT csv, HEADER true)

-- activity tables depend on properties + users ------------------------
\copy housing.price_changes (change_id, property_id, old_price, new_price, changed_at) FROM 'seed_data/price_changes.csv' WITH (FORMAT csv, HEADER true)

\copy housing.enquiries (enquiry_id, property_id, user_id, channel, message, created_at) FROM 'seed_data/enquiries.csv' WITH (FORMAT csv, HEADER true)

\copy housing.site_visits (visit_id, property_id, user_id, scheduled_at, status, feedback_rating) FROM 'seed_data/site_visits.csv' WITH (FORMAT csv, HEADER true)

\copy housing.shortlists (user_id, property_id, added_at) FROM 'seed_data/shortlists.csv' WITH (FORMAT csv, HEADER true)

ANALYZE;

-- ---------------------------------------------------------------------
-- Row counts after a successful load (seed_data.zip):
--   cities 10 · localities 100 · builders 150 · projects 1200
--   amenities 15 · project_amenities 6806 · users 40000
--   properties 120060 · price_changes 23425 · enquiries 100000
--   site_visits 35120 · shortlists 69999
-- Verify with:
--   SELECT relname, n_live_tup FROM pg_stat_user_tables
--   WHERE schemaname='housing' ORDER BY relname;
-- ---------------------------------------------------------------------
