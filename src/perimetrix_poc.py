# src/sentinel_poc.py

import os
import oracledb
from decimal import Decimal

# --- Configuration ---
# Load database credentials from environment variables
# IMPORTANT: Set these variables in your environment before running the script
# export DB_USER="your_user"
# export DB_PASSWORD="your_password"
# export DB_DSN="your_connect_string"
DB_USER = os.environ.get("DB_USER")
DB_PASSWORD = os.environ.get("DB_PASSWORD")
DB_DSN = os.environ.get("DB_DSN")

# --- Constants ---
# This is the decision threshold. If the vector distance to a "safe" pattern
# is below this value, we can consider the event non-threatening.
SAFE_PATTERN_SIMILARITY_THRESHOLD = 0.5


def get_db_connection():
    """Establishes a connection to the Oracle database."""
    if not all([DB_USER, DB_PASSWORD, DB_DSN]):
        raise ValueError(
            "Database environment variables (DB_USER, DB_PASSWORD, DB_DSN) must be set."
        )
    return oracledb.connect(user=DB_USER, password=DB_PASSWORD, dsn=DB_DSN)


def normalize_event(speed, dwell, proximity):
    """Normalizes raw event data into a vector-compatible format (0-1)."""
    # These max values should match the assumptions used in 05_seed_knowledge_base.sql
    max_speed = 60.0
    max_dwell = 60.0
    max_proximity = 50.0

    norm_speed = min(max_speed, speed) / max_speed
    norm_dwell = min(max_dwell, dwell) / max_dwell
    norm_proximity = min(max_proximity, proximity) / max_proximity

    return f"[{norm_speed:.3f}, {norm_dwell:.3f}, {norm_proximity:.3f}]"


def analyze_event(
    conn, parolee_id, lon, lat, speed, dwell, proximity
):
    """
    Inserts a tracking event and runs the hybrid query to analyze its threat level.
    """
    live_event_vector_str = normalize_event(speed, dwell, proximity)
    print(f"--- Analyzing Event for Parolee {parolee_id} ---")
    print(f"  Raw Data: Speed={speed}mph, Dwell={dwell}min, Proximity={proximity}ft")
    print(f"  Normalized Vector: {live_event_vector_str}")

    with conn.cursor() as cursor:
        try:
            # 1. Insert the new event
            location_geom = f"SDO_GEOMETRY(2001, 8307, SDO_POINT_TYPE({lon}, {lat}, NULL), NULL, NULL)"
            insert_sql = (
                f"INSERT INTO tracking_events (parolee_id, timestamp, speed_mph, location) "
                f"VALUES (:1, SYSTIMESTAMP, :2, {location_geom})"
            )
            cursor.execute(insert_sql, [parolee_id, speed])

            # 2. Run the hybrid query
            hybrid_query = """
                SELECT
                    b.description,
                    VECTOR_DISTANCE(b.behavior_vector, VECTOR(:vec, 3, FLOAT32)) as score
                FROM
                    tracking_events t, 
                    restricted_zones r,
                    behavior_patterns b
                WHERE
                    t.parolee_id = :p_id
                    AND t.timestamp > (SYSTIMESTAMP - INTERVAL '1' MINUTE) -- recent events
                    AND SDO_WITHIN_DISTANCE(t.location, r.shape, 'distance=914 unit=M') = 'TRUE'
                ORDER BY
                    score ASC
            """
            cursor.execute(hybrid_query, vec=live_event_vector_str, p_id=parolee_id)
            result = cursor.fetchone()

            if not result:
                print("  Result: Event is NOT within a restricted zone. No action needed.")
                return

            # 3. Analyze the result
            # A lower score means higher similarity to the pattern.
            best_match, similarity_score = result
            similarity_score = Decimal(similarity_score) # comes back as float

            print(f"  Best Match: '{best_match}' (Similarity Score: {similarity_score:.4f})")

            if "Safe" in best_match and similarity_score < SAFE_PATTERN_SIMILARITY_THRESHOLD:
                print(f"  DECISION: Alert DEPRIORITIZED (Score is below threshold of {SAFE_PATTERN_SIMILARITY_THRESHOLD})")
            else:
                print("  DECISION: Alert ELEVATED for officer attention!")

        except oracledb.DatabaseError as e:
            print(f"  Database Error: {e}")
        finally:
            # Clean up the event we just inserted to keep the test repeatable
            cursor.execute("DELETE FROM tracking_events WHERE parolee_id = :1", [parolee_id])
            conn.commit()


def main():
    """Main function to run the POC demonstration."""
    print("Starting Sentinel POC Demonstration...")
    try:
        conn = get_db_connection()
        print("Database connection successful.")

        # --- SCENARIO 1: Routine Event (Can be Deprioritized) ---
        # A person driving past the school at a reasonable speed.
        # Should be identified as a "Safe Traffic Detour" and deprioritized.
        analyze_event(
            conn=conn,
            parolee_id=101,
            lon=-73.995, lat=40.705,  # Inside school zone
            speed=45, dwell=1, proximity=5
        )

        # --- SCENARIO 2: Genuine Risk Event (Requires Officer Attention) ---
        # A person stopped inside the zone, off the main road.
        # Should be identified as "High Risk Loitering" and elevated.
        analyze_event(
            conn=conn,
            parolee_id=102,
            lon=-73.996, lat=40.706, # Inside school zone
            speed=1, dwell=25, proximity=45
        )

        # --- SCENARIO 3: Outside any zone ---
        # A person far away from any restricted zone.
        analyze_event(
            conn=conn,
            parolee_id=103,
            lon=-75.00, lat=41.00, # Far from school zone
            speed=60, dwell=5, proximity=5
        )

    except (ValueError, oracledb.DatabaseError) as e:
        print(f"An error occurred: {e}")
    finally:
        if 'conn' in locals() and conn:
            conn.close()
            print("\nDatabase connection closed.")
        print("Demonstration finished.")


if __name__ == "__main__":
    main()
