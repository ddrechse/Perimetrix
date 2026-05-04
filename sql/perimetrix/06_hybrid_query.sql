-- Phase 3, Step 6: The Hybrid Query (Spatial + Vector)
-- This is the core deliverable of the POC.
-- It detects geofence breaches and then enriches them with behavioral context through vector similarity.
--
-- The query returns one row per behavior pattern, scored against the incoming event vector.
-- ORDER BY similarity_score ASC puts the closest match first — that is the pattern the event
-- most resembles, and it drives the alert decision.  A lower score = higher similarity.
--
-- Two scenarios are demonstrated back to back so you can see the contrast in scores:
--   Scenario A (parolee 101): Routine — driving through at 45 mph.  Should match Safe Traffic Detour.
--   Scenario B (parolee 102): Risk    — loitering 25 min off-road.  Should match High Risk Loitering.


-- ─────────────────────────────────────────────────────
-- SCENARIO A: Routine transit — expect Safe Traffic Detour as closest match
-- Speed=45mph, Dwell=1min, Proximity=5ft
-- Vector: [45/60, 1/60, 5/50] = [0.75, 0.017, 0.10]
-- ─────────────────────────────────────────────────────
VARIABLE vec_a VARCHAR2(100);
EXEC :vec_a := '[0.75, 0.017, 0.10]';

INSERT INTO tracking_events (parolee_id, timestamp, speed_mph, heading, location) VALUES (
    101, SYSTIMESTAMP, 45, 90,
    SDO_GEOMETRY(2001, 8307, SDO_POINT_TYPE(-73.995, 40.705, NULL), NULL, NULL)
);
COMMIT;

PROMPT '';
PROMPT 'SCENARIO A — Parolee 101: Driving past school at 45 mph (routine)';
PROMPT 'Vector: [0.75, 0.017, 0.10]  |  Expect: Safe Traffic Detour scores lowest';
PROMPT '';
PROMPT 'HOW TO READ THE OUTPUT:';
PROMPT '  Each row shows the distance from this parolee''s behavior to ONE reference pattern.';
PROMPT '  Two rows = two patterns = two distance measurements. The parolee is not both things.';
PROMPT '  The row with the LOWEST score is the closest match — that is the alert decision.';
PROMPT '  The Python driver calls fetchone() to grab only that winning row.';

SELECT
    t.parolee_id,
    r.zone_name,
    b.description,
    ROUND(VECTOR_DISTANCE(b.behavior_vector, VECTOR(:vec_a, 3, FLOAT32)), 6) AS similarity_score
FROM
    tracking_events t,
    restricted_zones r,
    behavior_patterns b
WHERE
    t.parolee_id = 101
    AND SDO_WITHIN_DISTANCE(t.location, r.shape, 'distance=914 unit=M') = 'TRUE'
ORDER BY
    similarity_score ASC;

DELETE FROM tracking_events WHERE parolee_id = 101; COMMIT;


-- ─────────────────────────────────────────────────────
-- SCENARIO B: High-risk loitering — expect High Risk Loitering as closest match
-- Speed=1mph, Dwell=25min, Proximity=45ft
-- Vector: [1/60, 25/60, 45/50] = [0.017, 0.417, 0.90]
-- ─────────────────────────────────────────────────────
VARIABLE vec_b VARCHAR2(100);
EXEC :vec_b := '[0.017, 0.417, 0.90]';

INSERT INTO tracking_events (parolee_id, timestamp, speed_mph, heading, location) VALUES (
    102, SYSTIMESTAMP, 1, 0,
    SDO_GEOMETRY(2001, 8307, SDO_POINT_TYPE(-73.996, 40.706, NULL), NULL, NULL)
);
COMMIT;

PROMPT '';
PROMPT 'SCENARIO B — Parolee 102: Loitering near school for 25 minutes (risk)';
PROMPT 'Vector: [0.017, 0.417, 0.90]  |  Expect: High Risk Loitering scores lowest';

SELECT
    t.parolee_id,
    r.zone_name,
    b.description,
    ROUND(VECTOR_DISTANCE(b.behavior_vector, VECTOR(:vec_b, 3, FLOAT32)), 6) AS similarity_score
FROM
    tracking_events t,
    restricted_zones r,
    behavior_patterns b
WHERE
    t.parolee_id = 102
    AND SDO_WITHIN_DISTANCE(t.location, r.shape, 'distance=914 unit=M') = 'TRUE'
ORDER BY
    similarity_score ASC;

DELETE FROM tracking_events WHERE parolee_id = 102; COMMIT;

PROMPT '';
PROMPT 'Notice the score gap between the two patterns in each scenario.';
PROMPT 'A decisive gap is what the Python driver uses to make the alert decision.';
