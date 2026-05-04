-- Argus: Museum Security — Teardown
-- Drops all Argus schema objects in safe dependency order.
-- Run this before re-running the setup scripts on a persistent database.

-- 1. Drop spatial indexes (errors suppressed individually via PL/SQL)
BEGIN EXECUTE IMMEDIATE 'DROP INDEX argus_visitor_events_spatial_idx'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX argus_zone_features_spatial_idx';  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX argus_zones_spatial_idx';           EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- 2. Remove spatial metadata
DELETE FROM USER_SDO_GEOM_METADATA
WHERE TABLE_NAME IN ('ARGUS_ZONES', 'ARGUS_ZONE_FEATURES', 'ARGUS_VISITOR_EVENTS');
COMMIT;

-- 3. Drop tables
BEGIN EXECUTE IMMEDIATE 'DROP TABLE argus_behavior_patterns'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE argus_visitor_events';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE argus_zone_features';     EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE argus_zones';             EXCEPTION WHEN OTHERS THEN NULL; END;
/

PROMPT 'Argus teardown complete. Re-run 01 through 06 to reinitialize.';
