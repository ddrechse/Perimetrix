-- Phase 3, Step 6: The Hybrid Query (Spatial + Vector)
-- This is the core deliverable of the POC.
-- It finds geofence violations but then scores them against our behavior patterns.

-- 1. Simulate a new incoming event.
-- This event is a parolee stuck in traffic in the school zone.
-- Speed is low (10mph), but they are on a road (low proximity score).
-- Vector: [Speed, Dwell, Proximity] -> [10/60, 5/60, 8/50] -> [0.16, 0.08, 0.16]
VARIABLE live_event_vector VARCHAR2(100);
EXEC :live_event_vector := '[0.16, 0.08, 0.16]';

-- 2. Insert the event so the spatial query can find it.
INSERT INTO tracking_events (parolee_id, timestamp, speed_mph, heading, location) VALUES (
    456,
    SYSTIMESTAMP,
    10,
    90, -- Heading East
    SDO_GEOMETRY(
        2001, 8307, SDO_POINT_TYPE(-73.996, 40.706, NULL), NULL, NULL
    )
);
COMMIT;


-- 3. Run the Hybrid Query
PROMPT 'Running hybrid query for event from parolee 456 (stuck in traffic)...';
PROMPT 'A lower distance score means a HIGHER similarity to the behavior pattern.';

SELECT
    t.parolee_id,
    r.zone_name,
    b.description,
    VECTOR_DISTANCE(b.behavior_vector, VECTOR(:live_event_vector, 3, FLOAT32)) as similarity_score
FROM
    tracking_events t,
    restricted_zones r,
    behavior_patterns b
WHERE
    t.parolee_id = 456
    AND SDO_WITHIN_DISTANCE(t.location, r.shape, 'distance=914 unit=M') = 'TRUE'
ORDER BY
    similarity_score ASC;

PROMPT 'Query finished. The event should have a much lower score (higher similarity) for "Safe Traffic Detour".';
PROMPT 'This allows us to suppress the alert.';

-- Cleanup
-- DELETE FROM tracking_events WHERE parolee_id = 456;
-- COMMIT;
