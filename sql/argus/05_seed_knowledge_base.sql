-- Argus: Museum Security — Phase 2, Step 5
-- Seeds the behavioral knowledge base with two reference patterns.
--
-- Vector dimensions: [zone_coverage, dwell_normalized, camera_proximity_ratio]

-- Pattern 1: Casual Gallery Browse
--   A typical art enthusiast: modest coverage, moderate dwell, spends time near artwork
--   coverage       : 10% of room traversed        → 0.10
--   dwell          : 20 min / 60 min max           → 0.33
--   camera_prox    : 6% of pings near cameras      → 0.06  (mostly near art)
INSERT INTO argus_behavior_patterns (pattern_id, description, behavior_vector)
VALUES (1, 'Casual Gallery Browse', '[0.10, 0.33, 0.06]');

-- Pattern 2: Surveillance Casing
--   Systematic sweep: high coverage, long dwell, disproportionate time near cameras
--   coverage       : 80% of room traversed         → 0.80
--   dwell          : 30 min / 60 min max           → 0.50
--   camera_prox    : 85% of pings near cameras     → 0.85  (methodically mapping security)
INSERT INTO argus_behavior_patterns (pattern_id, description, behavior_vector)
VALUES (2, 'Surveillance Casing', '[0.80, 0.50, 0.85]');

COMMIT;

-- Verification:
-- SELECT pattern_id, description FROM argus_behavior_patterns;
-- Expected: 2 rows — 'Casual Gallery Browse', 'Surveillance Casing'
