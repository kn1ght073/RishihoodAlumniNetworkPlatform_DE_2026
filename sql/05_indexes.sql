-- =====================================================================
-- Housing.com DBMS Project — Phase 4 indexes
-- Team T0079 · PostgreSQL 15+
--
-- Apply after loading the seed data. These indexes target the filters,
-- joins, anti-joins, ordering and update lookups in workload_30.sql.
-- Run ANALYZE after creating them and benchmark with the supplied script.
-- =====================================================================
SET search_path TO housing;

-- Locality lookups used by rent, trend and city searches.
CREATE INDEX IF NOT EXISTS ix_localities_name_city
    ON housing.localities (locality_name, city_id, locality_id);

-- Property search filters. Partial predicates keep the indexes focused on
-- the active listing subsets used by the workload.
CREATE INDEX IF NOT EXISTS ix_properties_rent_search
    ON housing.properties (locality_id, bhk, price)
    INCLUDE (property_id, carpet_area_sqft, furnishing, available_from)
    WHERE listing_type = 'RENT' AND status = 'ACTIVE';

CREATE INDEX IF NOT EXISTS ix_properties_sale_search
    ON housing.properties (locality_id, bhk, price)
    INCLUDE (property_id, carpet_area_sqft)
    WHERE listing_type = 'SALE' AND status = 'ACTIVE'
      AND property_type = 'APARTMENT';

CREATE INDEX IF NOT EXISTS ix_properties_sale_trend
    ON housing.properties (locality_id, posted_at)
    INCLUDE (price, carpet_area_sqft)
    WHERE listing_type = 'SALE' AND property_type = 'APARTMENT';

CREATE INDEX IF NOT EXISTS ix_properties_map_rent
    ON housing.properties (latitude, longitude)
    INCLUDE (property_id, price, bhk)
    WHERE listing_type = 'RENT' AND status = 'ACTIVE';

-- Owner/agent dashboards, project pages, moderation and write lookups.
CREATE INDEX IF NOT EXISTS ix_properties_lister
    ON housing.properties (listed_by, property_id)
    INCLUDE (listing_type, status, price);

CREATE INDEX IF NOT EXISTS ix_properties_project_active
    ON housing.properties (project_id, status)
    INCLUDE (bhk, listing_type, price)
    WHERE project_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_properties_active_posted
    ON housing.properties (posted_at)
    INCLUDE (property_id, listed_by, listing_type, price)
    WHERE status = 'ACTIVE';

CREATE INDEX IF NOT EXISTS ix_properties_deal_posted
    ON housing.properties (posted_at, listed_by)
    WHERE status IN ('SOLD', 'RENTED');

CREATE INDEX IF NOT EXISTS ix_properties_locality_type
    ON housing.properties (locality_id, listing_type)
    INCLUDE (price, carpet_area_sqft)
    WHERE property_type = 'APARTMENT';

CREATE INDEX IF NOT EXISTS ix_properties_duplicate_check
    ON housing.properties
       (listed_by, locality_id, carpet_area_sqft, floor_no, bhk)
    WHERE status = 'ACTIVE';

CREATE INDEX IF NOT EXISTS ix_properties_posted_desc
    ON housing.properties (posted_at DESC)
    INCLUDE (property_id, listed_by, listing_type, status, price);

-- Child-side foreign key indexes support joins and correlated existence
-- checks. The composite key also supports the user/property pair lookups.
CREATE INDEX IF NOT EXISTS ix_enquiries_property_user
    ON housing.enquiries (property_id, user_id)
    INCLUDE (enquiry_id, created_at);

CREATE INDEX IF NOT EXISTS ix_enquiries_created
    ON housing.enquiries (created_at)
    INCLUDE (enquiry_id, property_id, user_id);

CREATE INDEX IF NOT EXISTS ix_site_visits_property_user
    ON housing.site_visits (property_id, user_id)
    INCLUDE (visit_id, scheduled_at);

CREATE INDEX IF NOT EXISTS ix_site_visits_scheduled
    ON housing.site_visits (scheduled_at, property_id)
    INCLUDE (visit_id, user_id);

CREATE INDEX IF NOT EXISTS ix_site_visits_rated
    ON housing.site_visits (property_id)
    WHERE feedback_rating IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_price_changes_changed
    ON housing.price_changes (changed_at)
    INCLUDE (property_id, old_price, new_price);

CREATE INDEX IF NOT EXISTS ix_project_amenities_amenity
    ON housing.project_amenities (amenity_id, project_id);

CREATE INDEX IF NOT EXISTS ix_amenities_name
    ON housing.amenities (amenity_name, amenity_id);

CREATE INDEX IF NOT EXISTS ix_shortlists_property_user
    ON housing.shortlists (property_id, user_id);

ANALYZE housing.localities;
ANALYZE housing.properties;
ANALYZE housing.enquiries;
ANALYZE housing.site_visits;
ANALYZE housing.price_changes;
ANALYZE housing.project_amenities;
ANALYZE housing.shortlists;
