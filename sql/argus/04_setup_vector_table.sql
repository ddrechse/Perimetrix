-- Argus: Museum Security — Phase 2, Step 4
-- Creates the table for behavioral reference patterns.
--
-- Same VECTOR(3, FLOAT32) type as Perimetrix — but the three dimensions
-- encode completely different domain signals:
--
--   Perimetrix: [speed/60,  dwell/60,  road_proximity_ft/50]
--   Argus:      [coverage,  dwell/60,  camera_proximity_ratio]
--
-- The SQL type is reused; the semantic space is domain-specific.
-- Choosing what to encode and how to normalize is the design decision.

CREATE TABLE argus_behavior_patterns (
    pattern_id      NUMBER PRIMARY KEY,
    description     VARCHAR2(100),
    behavior_vector VECTOR(3, FLOAT32)   -- [coverage, dwell_norm, camera_proximity]
) TABLESPACE USERS;

COMMIT;

-- Verification:
-- DESCRIBE argus_behavior_patterns;
-- Expected: VECTOR column type shown for behavior_vector
