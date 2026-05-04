-- Argus: Museum Security — Phase 1, Step 3
-- Demonstrates baseline zone-presence detection using SDO_INSIDE.
--
-- Perimetrix uses SDO_WITHIN_DISTANCE (outdoor GPS, approximate boundary).
-- Argus uses SDO_INSIDE     (indoor sensor grid, visitor is definitively IN a gallery).
-- Same architecture, different spatial operator — the domain dictates the choice.

-- 1. Seed the Impressionist Wing gallery zone
--    (coordinates near The Met, NYC — roughly 60m × 35m room footprint)
INSERT INTO argus_zones (zone_id, zone_name, zone_type, shape) VALUES (
    1,
    'Impressionist Wing',
    'GALLERY',
    SDO_GEOMETRY(
        2003, 8307, NULL,
        SDO_ELEM_INFO_ARRAY(1, 1003, 1),   -- exterior polygon, straight edges
        SDO_ORDINATE_ARRAY(
            -73.9640, 40.7790,   -- SW corner
            -73.9640, 40.7797,   -- NW corner
            -73.9625, 40.7797,   -- NE corner
            -73.9625, 40.7790,   -- SE corner
            -73.9640, 40.7790    -- closing point
        )
    )
);

-- 2. Seed the Modern Art Gallery
INSERT INTO argus_zones (zone_id, zone_name, zone_type, shape) VALUES (
    2,
    'Modern Art Gallery',
    'GALLERY',
    SDO_GEOMETRY(
        2003, 8307, NULL,
        SDO_ELEM_INFO_ARRAY(1, 1003, 1),
        SDO_ORDINATE_ARRAY(
            -73.9660, 40.7790,
            -73.9660, 40.7797,
            -73.9645, 40.7797,
            -73.9645, 40.7790,
            -73.9660, 40.7790
        )
    )
);

-- 3. Seed zone features — cameras and artwork inside the Impressionist Wing
--    Cameras are mounted in the four corners; artwork hangs along the walls.

-- Cameras (zone_id = 1)
INSERT INTO argus_zone_features (feature_id, zone_id, feature_type, feature_name, location) VALUES (
    1, 1, 'CAMERA', 'NW Camera',
    SDO_GEOMETRY(2001, 8307, SDO_POINT_TYPE(-73.9638, 40.7796, NULL), NULL, NULL)
);
INSERT INTO argus_zone_features (feature_id, zone_id, feature_type, feature_name, location) VALUES (
    2, 1, 'CAMERA', 'NE Camera',
    SDO_GEOMETRY(2001, 8307, SDO_POINT_TYPE(-73.9627, 40.7796, NULL), NULL, NULL)
);
INSERT INTO argus_zone_features (feature_id, zone_id, feature_type, feature_name, location) VALUES (
    3, 1, 'CAMERA', 'SW Camera',
    SDO_GEOMETRY(2001, 8307, SDO_POINT_TYPE(-73.9638, 40.7791, NULL), NULL, NULL)
);
INSERT INTO argus_zone_features (feature_id, zone_id, feature_type, feature_name, location) VALUES (
    4, 1, 'CAMERA', 'SE Camera',
    SDO_GEOMETRY(2001, 8307, SDO_POINT_TYPE(-73.9627, 40.7791, NULL), NULL, NULL)
);

-- Artwork (zone_id = 1)
INSERT INTO argus_zone_features (feature_id, zone_id, feature_type, feature_name, location) VALUES (
    5, 1, 'ARTWORK', 'Water Lilies',
    SDO_GEOMETRY(2001, 8307, SDO_POINT_TYPE(-73.9634, 40.7794, NULL), NULL, NULL)
);
INSERT INTO argus_zone_features (feature_id, zone_id, feature_type, feature_name, location) VALUES (
    6, 1, 'ARTWORK', 'Starry Night',
    SDO_GEOMETRY(2001, 8307, SDO_POINT_TYPE(-73.9631, 40.7794, NULL), NULL, NULL)
);
INSERT INTO argus_zone_features (feature_id, zone_id, feature_type, feature_name, location) VALUES (
    7, 1, 'ARTWORK', 'La Grande Jatte',
    SDO_GEOMETRY(2001, 8307, SDO_POINT_TYPE(-73.9633, 40.7792, NULL), NULL, NULL)
);
INSERT INTO argus_zone_features (feature_id, zone_id, feature_type, feature_name, location) VALUES (
    8, 1, 'ARTWORK', 'Impression Sunrise',
    SDO_GEOMETRY(2001, 8307, SDO_POINT_TYPE(-73.9630, 40.7792, NULL), NULL, NULL)
);

-- 4. Insert a test visitor ping inside the Impressionist Wing
INSERT INTO argus_visitor_events
    (visitor_id, timestamp, zone_coverage, dwell_minutes, location)
VALUES (
    9001,
    SYSTIMESTAMP,
    0.10, 20,
    SDO_GEOMETRY(2001, 8307, SDO_POINT_TYPE(-73.9632, 40.7793, NULL), NULL, NULL)
);

COMMIT;

-- 5. Baseline query: which visitors are inside a monitored gallery right now?
PROMPT 'Running baseline zone-presence query (SDO_INSIDE)...';

SELECT
    v.visitor_id,
    z.zone_name,
    v.dwell_minutes
FROM
    argus_visitor_events v,
    argus_zones          z
WHERE
    SDO_INSIDE(v.location, z.shape) = 'TRUE';

PROMPT 'Baseline query complete. Every visitor in a gallery fires an alert — no behavioral context yet.';

-- Cleanup
DELETE FROM argus_visitor_events WHERE visitor_id = 9001;
COMMIT;
