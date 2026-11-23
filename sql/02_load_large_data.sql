-- =====================================================================
-- Housing.com Property Search Database — Phase 5 data load (Large Dataset)
-- Team T0079 · CP4
--
-- Usage (run from repository root with large_data/ in place):
--   psql -d <your_large_database> -f sql/02_load_large_data.sql
-- =====================================================================

SET search_path TO housing;

-- reference data ------------------------------------------------------
\copy housing.cities (city_id, city_name, state) FROM 'large_data/cities.csv' WITH (FORMAT csv, HEADER true)

\copy housing.localities (locality_id, city_id, locality_name, pincode, center_lat, center_lng) FROM 'large_data/localities.csv' WITH (FORMAT csv, HEADER true)

\copy housing.builders (builder_id, builder_name, founded_year) FROM 'large_data/builders.csv' WITH (FORMAT csv, HEADER true)

-- projects depend on builders + localities ----------------------------
\copy housing.projects (project_id, builder_id, locality_id, project_name, rera_id, possession_status, possession_date, total_units) FROM 'large_data/projects.csv' WITH (FORMAT csv, HEADER true)

\copy housing.amenities (amenity_id, amenity_name) FROM 'large_data/amenities.csv' WITH (FORMAT csv, HEADER true)

\copy housing.project_amenities (project_id, amenity_id) FROM 'large_data/project_amenities.csv' WITH (FORMAT csv, HEADER true)

-- users before properties (properties.listed_by → users) --------------
\copy housing.users (user_id, full_name, phone, email, user_type, agent_rera_id, created_at) FROM 'large_data/users.csv' WITH (FORMAT csv, HEADER true)

\copy housing.properties (property_id, listed_by, project_id, locality_id, listing_type, property_type, bhk, carpet_area_sqft, floor_no, total_floors, furnishing, facing, price, maintenance_monthly, security_deposit, available_from, latitude, longitude, is_verified, status, posted_at) FROM 'large_data/properties.csv' WITH (FORMAT csv, HEADER true)

-- activity tables depend on properties + users ------------------------
\copy housing.price_changes (change_id, property_id, old_price, new_price, changed_at) FROM 'large_data/price_changes.csv' WITH (FORMAT csv, HEADER true)

\copy housing.enquiries (enquiry_id, property_id, user_id, channel, message, created_at) FROM 'large_data/enquiries.csv' WITH (FORMAT csv, HEADER true)

\copy housing.site_visits (visit_id, property_id, user_id, scheduled_at, status, feedback_rating) FROM 'large_data/site_visits.csv' WITH (FORMAT csv, HEADER true)

\copy housing.shortlists (user_id, property_id, added_at) FROM 'large_data/shortlists.csv' WITH (FORMAT csv, HEADER true)

ANALYZE;
