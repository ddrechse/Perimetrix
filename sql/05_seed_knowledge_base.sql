-- Phase 2, Step 5: Seed the "Knowledge Base"
-- We teach the system what "Safe" and "Unsafe" looks like by inserting reference vectors.

-- A "Safe Traffic Detour" vector:
-- Represents high speed, low dwell time, and close proximity to a road centerline.
-- Vector: [Speed, Dwell Time, Road Proximity]
-- Values are normalized (0 to 1). Let's use more illustrative values than the DemoPlan.
-- Speed: 45mph / 60mph max = 0.75
-- Dwell: 1 min / 60 mins max = 0.016
-- Proximity: 5 feet from centerline / 50 feet max = 0.1
INSERT INTO behavior_patterns (pattern_id, description, behavior_vector)
VALUES (1, 'Safe Traffic Detour', '[0.75, 0.016, 0.1]');


-- A "High Risk Loitering" vector:
-- Represents no speed, high dwell time, and being far from a road centerline (e.g., in a park).
-- Speed: 1mph / 60mph max = 0.016
-- Dwell: 30 mins / 60 mins max = 0.5
-- Proximity: 40 feet from centerline / 50 feet max = 0.8
INSERT INTO behavior_patterns (pattern_id, description, behavior_vector)
VALUES (2, 'High Risk Loitering', '[0.016, 0.5, 0.8]');

COMMIT;

-- Verification:
-- SELECT pattern_id, description FROM behavior_patterns;
-- Expected: 2 rows should be returned ('Safe Traffic Detour', 'High Risk Loitering').
