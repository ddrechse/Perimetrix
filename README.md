# Perimetrix + Argus — Behavioral Vector POC

This repository demonstrates two real-world implementations of the same Oracle Database 26ai converged architecture: **Oracle Spatial + AI Vector Search in a single SQL query**.

| Use Case | System | Domain | Spatial Operator |
|---|---|---|---|
| Parolee monitoring | **Perimetrix** | Outdoor GPS tracking | `SDO_WITHIN_DISTANCE` |
| Museum security | **Argus** | Indoor sensor grid | `SDO_INSIDE` |

The key CS insight: both systems use `VECTOR(3, FLOAT32)` and `VECTOR_DISTANCE(COSINE)` — but the three dimensions encode completely different domain signals. The architecture is reusable; the feature engineering is domain-specific.

| Dimension | Perimetrix | Argus |
|---|---|---|
| 1 | speed / 60 mph | zone\_coverage (0–1) |
| 2 | dwell\_time / 60 min | dwell\_time / 60 min |
| 3 | road\_proximity\_ft / 50 | camera\_proximity\_ratio (0–1) |

---

## Prerequisites

- Python 3.8+
- Docker installed and running
- SQLcl — Oracle's command-line interface for running SQL scripts against an Oracle database. It's a lightweight Java-based tool (no full client install required) that supports Oracle-specific features like the `@script.sql` syntax used in this project. [Download SQLcl here](https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/)

---

## 1. Setup

### a) Start Oracle Database 26ai (Docker)

```bash
docker run -d \
  --name oracle23ai \
  -p 1521:1521 \
  -e ORACLE_PASSWORD=YourPassword123 \
  gvenzl/oracle-free:latest
```

Wait until `docker logs oracle23ai` shows **"DATABASE IS READY TO USE!"** (10–20 seconds).

### b) Python dependencies

```bash
pip install -r requirements.txt
```

### c) Environment variables

```bash
export DB_USER="SYSTEM"
export DB_PASSWORD="YourPassword123"
export DB_DSN="localhost:1521/FREEPDB1"
```

---

## 2. Database Initialization

> **Note for persistent databases:** If you are running against a shared or long-lived Oracle instance rather than a fresh Docker container, the tables from a previous run may already exist. Running the `01_setup_schema.sql` scripts will fail with `ORA-00955: name is already used by an existing object`. In that case, drop the existing tables manually before proceeding, or skip to the script that failed and continue from there. The Docker container approach used in this POC starts clean every time, so this is not an issue in that setup.

Connect with SQLcl:

```bash
sql SYSTEM/YourPassword123@localhost:1521/FREEPDB1
```

### Perimetrix (parolee monitoring)

**Phase 1 — Spatial Foundation**

```sql
@sql/perimetrix/01_setup_schema.sql
```
Creates two tables: `restricted_zones` (school zones and parks stored as `SDO_GEOMETRY` polygons) and `tracking_events` (ankle monitor GPS pings stored as `SDO_GEOMETRY` points with speed and timestamp).

```sql
@sql/perimetrix/02_configure_spatial_metadata.sql
```
Registers both geometry columns with Oracle's spatial metadata catalog and builds R-tree indexes on each. This is what enables sub-second `SDO_WITHIN_DISTANCE` queries at scale.

```sql
@sql/perimetrix/03_legacy_alert_logic.sql
```
Seeds Central High School as a zone polygon, inserts a test GPS ping inside it, and runs the baseline geofencing query using `SDO_WITHIN_DISTANCE`. This demonstrates the existing capability — and the problem: every ping inside the zone fires an alert regardless of context.

**Phase 2 — Vector Intelligence**

```sql
@sql/perimetrix/04_setup_vector_table.sql
```
Creates the `behavior_patterns` table with a `VECTOR(3, FLOAT32)` column. The three dimensions represent normalized speed, dwell time, and road proximity — the behavioral fingerprint of a GPS event.

```sql
@sql/perimetrix/05_seed_knowledge_base.sql
```
Inserts two reference behavioral patterns: `Safe Traffic Detour` [0.75, 0.016, 0.10] (fast, brief, on-road) and `High Risk Loitering` [0.016, 0.5, 0.8] (slow, long dwell, off-road). These are the anchors the system measures incoming events against.

**Phase 3 — Hybrid Query**

```sql
@sql/perimetrix/06_hybrid_query.sql
```
Runs the full hybrid query: `SDO_WITHIN_DISTANCE` filters to zone breaches, then `VECTOR_DISTANCE(COSINE)` scores the event against both reference patterns in the same SQL statement. The closest matching pattern determines whether the alert is deprioritized or elevated.

---

### Argus (museum security)

**Phase 1 — Spatial Foundation**

```sql
@sql/argus/01_setup_schema.sql
```
Creates three tables: `argus_zones` (gallery polygons), `argus_zone_features` (cameras and artwork stored as `SDO_GEOMETRY` points inside each gallery), and `argus_visitor_events` (visitor sensor pings with zone coverage % and dwell minutes). Note: `camera_proximity_ratio` is **not** stored — it is computed dynamically from `argus_zone_features` at query time.

```sql
@sql/argus/02_configure_spatial_metadata.sql
```
Registers all three geometry columns (`argus_zones.shape`, `argus_zone_features.location`, `argus_visitor_events.location`) and builds R-tree indexes on each.

```sql
@sql/argus/03_legacy_alert_logic.sql
```
Seeds the Impressionist Wing and Modern Art Gallery as zone polygons, seeds four corner cameras and four artwork positions into `argus_zone_features`, inserts a test visitor ping, and runs the baseline query using `SDO_INSIDE`. Note the operator difference from Perimetrix: indoor sensor grids are precise, so we use exact containment rather than a distance buffer.

**Phase 2 — Vector Intelligence**

```sql
@sql/argus/04_setup_vector_table.sql
```
Creates the `argus_behavior_patterns` table with a `VECTOR(3, FLOAT32)` column. The three dimensions are zone coverage ratio, normalized dwell time, and camera proximity ratio — a completely different feature space from Perimetrix, using the same SQL type.

```sql
@sql/argus/05_seed_knowledge_base.sql
```
Inserts two reference patterns: `Casual Gallery Browse` [0.10, 0.33, 0.06] (low coverage, moderate dwell, near artwork) and `Surveillance Casing` [0.80, 0.50, 0.85] (high coverage, high dwell, near cameras). These sit at opposite poles of the museum behavioral space.

**Phase 3 — Hybrid Query**

```sql
@sql/argus/06_hybrid_query.sql
```
Runs the full hybrid query: `SDO_INSIDE` confirms the visitor is within a gallery, then `VECTOR_DISTANCE(COSINE)` scores their behavioral vector against both reference patterns. The closest match drives the security decision.

---

## 3. Running the Demonstrations

### Perimetrix — three scenarios

```bash
python src/perimetrix_poc.py
```

Expected output:
```
--- Analyzing Event for Parolee 101 ---
  Raw Data: Speed=45mph, Dwell=1min, Proximity=5ft
  Normalized Vector: [0.750, 0.017, 0.100]
  Best Match: 'Safe Traffic Detour' (Similarity Score: 0.0001)
  DECISION: Alert DEPRIORITIZED

--- Analyzing Event for Parolee 102 ---
  Raw Data: Speed=1mph, Dwell=25min, Proximity=45ft
  Normalized Vector: [0.017, 0.417, 0.900]
  Best Match: 'High Risk Loitering' (Similarity Score: 0.0139)
  DECISION: Alert ELEVATED for officer attention!

--- Analyzing Event for Parolee 103 ---
  Result: Event is NOT within a restricted zone. No action needed.
```

### Argus — two scenarios

```bash
python src/argus_poc.py
```

Expected output:
```
--- Analyzing Event for Visitor 4471 ---
  Raw Data : Coverage=15%,  Dwell=20min,  Camera proximity=6%
  Behavioral Vector : [0.150, 0.333, 0.063]
  Best Match : 'Casual Gallery Browse'  (Similarity Score: ~0.0)
  DECISION : Alert DEPRIORITIZED — routine visitor behavior

--- Analyzing Event for Visitor 4472 ---
  Raw Data : Coverage=50%,  Dwell=30min,  Camera proximity=80%
  Behavioral Vector : [0.500, 0.500, 0.800]
  Best Match : 'Surveillance Casing'  (Similarity Score: ~0.02)
  DECISION : Alert ELEVATED — security review recommended!
```

`camera_proximity_ratio` is computed live: for each sensor ping, `argus_poc.py` queries `argus_zone_features` via `SDO_GEOM.SDO_DISTANCE` to find the nearest feature. The fraction of pings nearest to a CAMERA (vs. ARTWORK) becomes the third vector dimension.

---

## 4. Resetting Test Data

```bash
sql SYSTEM/YourPassword123@localhost:1521/FREEPDB1
```

```sql
@sql/perimetrix/clean_duplicates.sql
@sql/argus/clean_duplicates.sql
```
