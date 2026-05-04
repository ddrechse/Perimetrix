-- Argus: Museum Security — Phase 1, Step 2
-- Registers geometry columns with Oracle Spatial and builds R-tree indexes.
-- All three tables with geometry columns are registered here.

INSERT INTO USER_SDO_GEOM_METADATA (TABLE_NAME, COLUMN_NAME, DIMINFO, SRID) VALUES (
    'ARGUS_ZONES',
    'SHAPE',
    SDO_DIM_ARRAY(
        SDO_DIM_ELEMENT('X', -180, 180, 0.005),  -- Longitude
        SDO_DIM_ELEMENT('Y',  -90,  90, 0.005)   -- Latitude
    ),
    8307  -- WGS84
);

INSERT INTO USER_SDO_GEOM_METADATA (TABLE_NAME, COLUMN_NAME, DIMINFO, SRID) VALUES (
    'ARGUS_ZONE_FEATURES',
    'LOCATION',
    SDO_DIM_ARRAY(
        SDO_DIM_ELEMENT('X', -180, 180, 0.005),
        SDO_DIM_ELEMENT('Y',  -90,  90, 0.005)
    ),
    8307
);

INSERT INTO USER_SDO_GEOM_METADATA (TABLE_NAME, COLUMN_NAME, DIMINFO, SRID) VALUES (
    'ARGUS_VISITOR_EVENTS',
    'LOCATION',
    SDO_DIM_ARRAY(
        SDO_DIM_ELEMENT('X', -180, 180, 0.005),
        SDO_DIM_ELEMENT('Y',  -90,  90, 0.005)
    ),
    8307
);

COMMIT;

CREATE INDEX argus_zones_spatial_idx
    ON argus_zones(shape)
    INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2;

CREATE INDEX argus_zone_features_spatial_idx
    ON argus_zone_features(location)
    INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2;

CREATE INDEX argus_visitor_events_spatial_idx
    ON argus_visitor_events(location)
    INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2;

-- Verification:
-- SELECT index_name, status FROM user_indexes
--   WHERE index_name IN ('ARGUS_ZONES_SPATIAL_IDX',
--                        'ARGUS_ZONE_FEATURES_SPATIAL_IDX',
--                        'ARGUS_VISITOR_EVENTS_SPATIAL_IDX');
-- Expected: All three VALID
