-- Phase 1, Step 3: Demonstrate Baseline Geofencing
-- This script demonstrates the current effective geofencing capability that detects boundary breaches.
-- Phase 2 will enhance this with contextual intelligence to distinguish routine events from genuine risks.

-- 1. Insert a dummy school zone
-- A rectangular polygon representing a school zone
INSERT INTO restricted_zones (zone_id, zone_name, zone_type, shape) VALUES (
    1,
    'Central High School Zone',
    'SCHOOL',
    SDO_GEOMETRY(
        2003,  -- 2D Polygon
        8307,
        NULL,
        SDO_ELEM_INFO_ARRAY(1, 1003, 1), -- exterior polygon
        SDO_ORDINATE_ARRAY(
            -74.00, 40.70,  -- Bottom-left
            -74.00, 40.71,  -- Top-left
            -73.99, 40.71,  -- Top-right
            -73.99, 40.70,  -- Bottom-right
            -74.00, 40.70   -- Closing point
        )
    )
);

-- 2. Insert a test "ping" that is driving *past* the school at high speed
-- The location is inside the zone, but the speed suggests transient movement.
INSERT INTO tracking_events (parolee_id, timestamp, speed_mph, heading, location) VALUES (
    123,
    SYSTIMESTAMP,
    45,
    90, -- Heading East
    SDO_GEOMETRY(
        2001, -- 2D Point
        8307,
        SDO_POINT_TYPE(-73.995, 40.705, NULL), -- A point within the school zone polygon
        NULL,
        NULL
    )
);

COMMIT;

-- 3. Run the standard spatial query to detect boundary breaches
-- This query finds any ping within 1000 yards of a school using proven geofencing capabilities.
-- Phase 2 will enhance this with behavioral context (speed, dwell time, etc.).
-- NOTE: 914 meters is approximately 1000 yards.
PROMPT 'Running baseline geofencing query to detect boundary breaches...';

SELECT
    t.event_id,
    t.parolee_id,
    r.zone_name,
    t.speed_mph
FROM
    tracking_events t,
    restricted_zones r
WHERE
    SDO_WITHIN_DISTANCE(t.location, r.shape, 'distance=914 unit=M') = 'TRUE'
    AND r.zone_type = 'SCHOOL';

PROMPT 'Query finished. The row returned demonstrates effective boundary detection.';

-- Cleanup (optional)
-- DELETE FROM tracking_events;
-- DELETE FROM restricted_zones;
-- COMMIT;
