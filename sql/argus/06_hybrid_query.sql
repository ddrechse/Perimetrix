-- Argus: Museum Security — Phase 3, Step 6
-- The hybrid query: spatial containment + vector similarity in one statement.
--
-- Perimetrix used SDO_WITHIN_DISTANCE (outdoor, approximate).
-- Argus uses SDO_INSIDE (indoor sensor grid, exact containment).
-- Both call VECTOR_DISTANCE(COSINE) — same function, different feature space.
--
-- The query returns one row per behavior pattern, scored against the incoming event vector.
-- ORDER BY similarity_score ASC puts the closest match first — that is the pattern the event
-- most resembles, and it drives the alert decision.  A lower score = higher similarity.
--
-- Two scenarios are demonstrated back to back so you can see the contrast in scores:
--   Scenario A (visitor 4471): Routine — casual art browsing. Should match Casual Gallery Browse.
--   Scenario B (visitor 4472): Risk    — systematic camera mapping. Should match Surveillance Casing.


-- ─────────────────────────────────────────────────────
-- SCENARIO A: Casual art visitor — expect Casual Gallery Browse as closest match
-- Coverage=10%, Dwell=20min, Camera proximity=6%
-- Vector: [0.10, 20/60, 0.06] = [0.10, 0.33, 0.06]
-- ─────────────────────────────────────────────────────
VARIABLE vec_a VARCHAR2(100);
EXEC :vec_a := '[0.10, 0.33, 0.06]';

INSERT INTO argus_visitor_events
    (visitor_id, timestamp, zone_coverage, dwell_minutes, location)
VALUES (
    4471, SYSTIMESTAMP, 0.10, 20,
    SDO_GEOMETRY(2001, 8307, SDO_POINT_TYPE(-73.9632, 40.7793, NULL), NULL, NULL)
);
COMMIT;

PROMPT '';
PROMPT 'SCENARIO A — Visitor 4471: Casual art browsing (routine)';
PROMPT 'Vector: [0.10, 0.33, 0.06]  |  Expect: Casual Gallery Browse scores lowest';
PROMPT '';
PROMPT 'HOW TO READ THE OUTPUT:';
PROMPT '  Each row shows the distance from this visitor''s behavior to ONE reference pattern.';
PROMPT '  Two rows = two patterns = two distance measurements. The visitor is not both things.';
PROMPT '  The row with the LOWEST score is the closest match — that is the alert decision.';
PROMPT '  The Python driver calls fetchone() to grab only that winning row.';

SELECT
    v.visitor_id,
    z.zone_name,
    b.description,
    ROUND(VECTOR_DISTANCE(b.behavior_vector, VECTOR(:vec_a, 3, FLOAT32)), 6) AS similarity_score
FROM
    argus_visitor_events v,
    argus_zones          z,
    argus_behavior_patterns b
WHERE
    v.visitor_id = 4471
    AND SDO_INSIDE(v.location, z.shape) = 'TRUE'
ORDER BY
    similarity_score ASC;

DELETE FROM argus_visitor_events WHERE visitor_id = 4471; COMMIT;


-- ─────────────────────────────────────────────────────
-- SCENARIO B: Surveillance casing — expect Surveillance Casing as closest match
-- Coverage=80%, Dwell=30min, Camera proximity=85%
-- Vector: [0.80, 30/60, 0.85] = [0.80, 0.50, 0.85]
-- ─────────────────────────────────────────────────────
VARIABLE vec_b VARCHAR2(100);
EXEC :vec_b := '[0.80, 0.50, 0.85]';

INSERT INTO argus_visitor_events
    (visitor_id, timestamp, zone_coverage, dwell_minutes, location)
VALUES (
    4472, SYSTIMESTAMP, 0.80, 30,
    SDO_GEOMETRY(2001, 8307, SDO_POINT_TYPE(-73.9633, 40.7794, NULL), NULL, NULL)
);
COMMIT;

PROMPT '';
PROMPT 'SCENARIO B — Visitor 4472: Systematic camera mapping (risk)';
PROMPT 'Vector: [0.80, 0.50, 0.85]  |  Expect: Surveillance Casing scores lowest';
PROMPT '';
PROMPT 'HOW TO READ THE OUTPUT:';
PROMPT '  Each row shows the distance from this visitor''s behavior to ONE reference pattern.';
PROMPT '  Two rows = two patterns = two distance measurements. The visitor is not both things.';
PROMPT '  The row with the LOWEST score is the closest match — that is the alert decision.';
PROMPT '  The Python driver calls fetchone() to grab only that winning row.';

SELECT
    v.visitor_id,
    z.zone_name,
    b.description,
    ROUND(VECTOR_DISTANCE(b.behavior_vector, VECTOR(:vec_b, 3, FLOAT32)), 6) AS similarity_score
FROM
    argus_visitor_events v,
    argus_zones          z,
    argus_behavior_patterns b
WHERE
    v.visitor_id = 4472
    AND SDO_INSIDE(v.location, z.shape) = 'TRUE'
ORDER BY
    similarity_score ASC;

DELETE FROM argus_visitor_events WHERE visitor_id = 4472; COMMIT;

PROMPT '';
PROMPT 'Notice the score gap between the two patterns in each scenario.';
PROMPT 'A decisive gap is what the Python driver uses to make the alert decision.';
