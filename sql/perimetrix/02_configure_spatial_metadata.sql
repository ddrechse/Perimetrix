-- Phase 1, Step 2: Configure Geospatial Metadata & Indexes
-- Registers the geometry columns with Oracle's spatial metadata and creates indexes.

-- Register metadata for RESTRICTED_ZONES table
INSERT INTO USER_SDO_GEOM_METADATA (TABLE_NAME, COLUMN_NAME, DIMINFO, SRID)
VALUES (
  'RESTRICTED_ZONES',
  'SHAPE',
  SDO_DIM_ARRAY(
    SDO_DIM_ELEMENT('X', -180, 180, 0.005), -- Longitude
    SDO_DIM_ELEMENT('Y', -90, 90, 0.005)   -- Latitude
  ),
  8307 -- SRID for WGS84 (standard GPS coordinates)
);

-- Register metadata for TRACKING_EVENTS table
INSERT INTO USER_SDO_GEOM_METADATA (TABLE_NAME, COLUMN_NAME, DIMINFO, SRID)
VALUES (
  'TRACKING_EVENTS',
  'LOCATION',
  SDO_DIM_ARRAY(
    SDO_DIM_ELEMENT('X', -180, 180, 0.005), -- Longitude
    SDO_DIM_ELEMENT('Y', -90, 90, 0.005)   -- Latitude
  ),
  8307 -- SRID for WGS84
);

COMMIT;

-- Create Spatial Indexes (R-tree) for fast spatial queries
CREATE INDEX restricted_zones_spatial_idx ON restricted_zones(shape) INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2;
CREATE INDEX tracking_events_spatial_idx ON tracking_events(location) INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2;

-- Verification:
-- SELECT index_name, status FROM user_indexes WHERE index_name IN ('RESTRICTED_ZONES_SPATIAL_IDX', 'TRACKING_EVENTS_SPATIAL_IDX');
-- Expected: Both indexes should be listed with status 'VALID'.
