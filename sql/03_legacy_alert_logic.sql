-- Phase 1, Step 3: Implement the "Legacy" Alert Logic
-- This script demonstrates the "false positive" problem by generating an alert for a non-threatening event.

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

-- 3. Run the standard spatial query to find alerts
-- This query finds any ping within 1000 yards of a school, ignoring context like speed.
-- NOTE: 914 meters is approximately 1000 yards.
PROMPT 'Running legacy query to find alerts based only on distance...';

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

PROMPT 'Query finished. The row returned represents the "false positive" alert.';

-- Cleanup (optional)
-- DELETE FROM tracking_events;
-- DELETE FROM restricted_zones;
-- COMMIT;
