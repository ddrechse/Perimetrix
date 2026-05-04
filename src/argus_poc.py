# src/argus_poc.py
# Argus — Museum Security POC
#
# Demonstrates the same Oracle Spatial + AI Vector architecture as Perimetrix,
# applied to an indoor museum security context.
#
# Perimetrix vector: [speed/60, dwell/60, road_proximity_ft/50]
# Argus vector:      [zone_coverage, dwell/60, camera_proximity_ratio]
#
# camera_proximity_ratio is NOT stored in the database. It is computed live by
# querying argus_zone_features and finding, for each sensor ping, whether the
# nearest feature is a CAMERA or ARTWORK. This mirrors the slide architecture
# that shows three tables feeding the behavioral vector calculation.

import os
import oracledb
from decimal import Decimal

# --- Configuration ---
DB_USER     = os.environ.get("DB_USER")
DB_PASSWORD = os.environ.get("DB_PASSWORD")
DB_DSN      = os.environ.get("DB_DSN")

# Number of distinct sensor-grid cells in a gallery. Used to normalize coverage.
# A gallery divided into a 4×5 grid has 20 positions.
GALLERY_CAPACITY = 20

# Decision threshold: if the cosine distance to the "safe" pattern is below
# this value the visit is routine enough to deprioritize.
SAFE_PATTERN_SIMILARITY_THRESHOLD = 0.5


def get_db_connection():
    if not all([DB_USER, DB_PASSWORD, DB_DSN]):
        raise ValueError(
            "Database environment variables (DB_USER, DB_PASSWORD, DB_DSN) must be set."
        )
    return oracledb.connect(user=DB_USER, password=DB_PASSWORD, dsn=DB_DSN)


def compute_coverage(ping_locations):
    """
    Estimates what fraction of the gallery the visitor covered.

    Uses the number of distinct (lon, lat) positions across all pings, divided
    by GALLERY_CAPACITY (the number of cells in the sensor grid).
    Capped at 1.0.
    """
    unique_positions = len(set(ping_locations))
    return round(min(1.0, unique_positions / GALLERY_CAPACITY), 3)


def compute_camera_proximity_ratio(conn, ping_locations):
    """
    For each sensor ping, finds the nearest feature in argus_zone_features
    (CAMERA or ARTWORK) using SDO_GEOM.SDO_DISTANCE. Returns the fraction of
    pings whose nearest feature is a CAMERA.

    This is the dynamic version of camera_proximity_ratio — computed from
    real spatial data rather than stored as a pre-computed column.
    """
    if not ping_locations:
        return 0.0

    camera_count = 0
    with conn.cursor() as cursor:
        for lon, lat in ping_locations:
            cursor.execute(
                """
                SELECT feature_type
                FROM (
                    SELECT feature_type,
                           SDO_GEOM.SDO_DISTANCE(
                               location,
                               SDO_GEOMETRY(2001, 8307,
                                   SDO_POINT_TYPE(:lon, :lat, NULL), NULL, NULL),
                               0.005
                           ) AS dist
                    FROM argus_zone_features
                    ORDER BY dist
                )
                WHERE ROWNUM = 1
                """,
                lon=lon, lat=lat
            )
            row = cursor.fetchone()
            if row and row[0] == 'CAMERA':
                camera_count += 1

    return round(camera_count / len(ping_locations), 3)


def analyze_visitor(conn, visitor_id, ping_locations, dwell_minutes, representative_ping):
    """
    Inserts a single representative visitor event and runs the hybrid
    spatial + vector query to classify the visit as routine or suspicious.

    ping_locations     : list of (lon, lat) tuples — the visitor's sensor trail
    representative_ping: (lon, lat) used for the SDO_GEOMETRY in the event row
                         (typically the most central observed position)
    """
    zone_coverage          = compute_coverage(ping_locations)
    camera_proximity_ratio = compute_camera_proximity_ratio(conn, ping_locations)
    dwell_norm             = round(min(60.0, dwell_minutes) / 60.0, 3)
    vector_str             = f"[{zone_coverage:.3f}, {dwell_norm:.3f}, {camera_proximity_ratio:.3f}]"

    lon, lat = representative_ping

    print(f"--- Analyzing Event for Visitor {visitor_id} ---")
    print(f"  Raw Data : Coverage={zone_coverage:.0%},  "
          f"Dwell={dwell_minutes}min,  "
          f"Camera proximity={camera_proximity_ratio:.0%}")
    print(f"  Behavioral Vector : {vector_str}")

    with conn.cursor() as cursor:
        try:
            # 1. Insert a single representative visitor event
            cursor.execute(
                f"INSERT INTO argus_visitor_events "
                f"(visitor_id, timestamp, zone_coverage, dwell_minutes, location) "
                f"VALUES (:1, SYSTIMESTAMP, :2, :3, "
                f"SDO_GEOMETRY(2001, 8307, SDO_POINT_TYPE({lon}, {lat}, NULL), NULL, NULL))",
                [visitor_id, zone_coverage, dwell_minutes]
            )

            # 2. Hybrid query: SDO_INSIDE (zone containment) + VECTOR_DISTANCE (behavior)
            hybrid_query = """
                SELECT
                    b.description,
                    VECTOR_DISTANCE(
                        b.behavior_vector,
                        VECTOR(:vec, 3, FLOAT32)
                    ) AS similarity_score
                FROM
                    argus_visitor_events v,
                    argus_zones          z,
                    argus_behavior_patterns b
                WHERE
                    v.visitor_id = :v_id
                    AND v.timestamp > (SYSTIMESTAMP - INTERVAL '1' MINUTE)
                    AND SDO_INSIDE(v.location, z.shape) = 'TRUE'
                ORDER BY
                    similarity_score ASC
            """
            cursor.execute(hybrid_query, vec=vector_str, v_id=visitor_id)
            result = cursor.fetchone()

            if not result:
                print("  Result  : Visitor is NOT inside a monitored gallery. No action needed.")
                return

            best_match, similarity_score = result
            similarity_score = Decimal(similarity_score)

            print(f"  Best Match : '{best_match}'  (Similarity Score: {similarity_score:.4f})")

            if "Casual" in best_match and similarity_score < SAFE_PATTERN_SIMILARITY_THRESHOLD:
                print("  DECISION : Alert DEPRIORITIZED — routine visitor behavior")
            else:
                print("  DECISION : Alert ELEVATED — security review recommended!")

        except oracledb.DatabaseError as e:
            print(f"  Database Error: {e}")
        finally:
            cursor.execute(
                "DELETE FROM argus_visitor_events WHERE visitor_id = :1", [visitor_id]
            )
            conn.commit()


def main():
    print("Starting Argus POC Demonstration — Museum Security")
    print("=" * 58)
    try:
        conn = get_db_connection()
        print("Database connection successful.\n")

        # --- SCENARIO 1: Casual art enthusiast (Deprioritize) ---
        # 16 pings: 15 clustered near artwork (Water Lilies, Starry Night,
        # La Grande Jatte, Impression Sunrise), 1 near the NW camera.
        # Expected: coverage ≈ 0.15, camera_ratio ≈ 0.06
        casual_pings = [
            (-73.9634, 40.7794),   # Water Lilies — 4 pings
            (-73.9634, 40.7794),
            (-73.9634, 40.7794),
            (-73.9634, 40.7794),
            (-73.9631, 40.7794),   # Starry Night — 4 pings
            (-73.9631, 40.7794),
            (-73.9631, 40.7794),
            (-73.9631, 40.7794),
            (-73.9633, 40.7792),   # La Grande Jatte — 4 pings
            (-73.9633, 40.7792),
            (-73.9633, 40.7792),
            (-73.9633, 40.7792),
            (-73.9630, 40.7792),   # Impression Sunrise — 2 pings
            (-73.9630, 40.7792),
            (-73.9630, 40.7792),
            (-73.9638, 40.7796),   # NW Camera — 1 ping (brief glance)
        ]
        analyze_visitor(
            conn=conn,
            visitor_id=4471,
            ping_locations=casual_pings,
            dwell_minutes=20,
            representative_ping=(-73.9632, 40.7793)   # center of wing
        )
        print()

        # --- SCENARIO 2: Surveillance casing (Elevate) ---
        # 10 pings: 8 near the four corner cameras (systematic sweep),
        # 2 near artwork. Expected: coverage ≈ 0.50, camera_ratio ≈ 0.80
        surveillance_pings = [
            (-73.9638, 40.7796),   # NW Camera — 2 pings
            (-73.9638, 40.7796),
            (-73.9627, 40.7796),   # NE Camera — 2 pings
            (-73.9627, 40.7796),
            (-73.9638, 40.7791),   # SW Camera — 2 pings
            (-73.9638, 40.7791),
            (-73.9627, 40.7791),   # SE Camera — 2 pings
            (-73.9627, 40.7791),
            (-73.9634, 40.7794),   # Water Lilies — 1 ping
            (-73.9631, 40.7794),   # Starry Night — 1 ping
        ]
        analyze_visitor(
            conn=conn,
            visitor_id=4472,
            ping_locations=surveillance_pings,
            dwell_minutes=30,
            representative_ping=(-73.9633, 40.7794)   # center of wing
        )
        print()

    except (ValueError, oracledb.DatabaseError) as e:
        print(f"An error occurred: {e}")
    finally:
        if 'conn' in locals() and conn:
            conn.close()
            print("Database connection closed.")
        print("Demonstration finished.")


if __name__ == "__main__":
    main()
