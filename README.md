# Perimetrix - Intelligent Geospatial Monitoring POC

This project is a Proof of Concept (POC) for an intelligent geospatial monitoring system.

It uses **Oracle Database 23ai** to unlock the contextual intelligence potential of traditional geospatial monitoring systems. By combining native Spatial capabilities with **AI Vector Search**, the system enhances existing geofencing with behavioral context, enabling it to distinguish between routine events (like a user driving through a restricted zone) and genuine risk behaviors (like loitering in one). This optimization helps buffer officers from false positives while elevating true threats from the noise.

## Prerequisites

- Python 3.8+
- Docker installed and running
- SQLcl (Oracle SQL Command Line) - [Download here](https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/)

## 1. Setup

### a) Clone the Repository
```bash
git clone <YOUR_GITHUB_REPO_URL>
cd 
```

### b) Start Oracle Database 23ai Docker Container

Pull and run the Oracle Database 23ai Free Docker container:

```bash
docker run -d \
  --name oracle23ai \
  -p 1521:1521 \
  -e ORACLE_PASSWORD=YourPassword123 \
  gvenzl/oracle-free:latest
```

**Notes:**
- The container may take 1-2 minutes to fully start
- Default database name: `FREEPDB1`
- Default admin user: `SYSTEM`
- Replace `YourPassword123` with your preferred password

Check container status:
```bash
docker logs oracle23ai
```

Wait for the message "DATABASE IS READY TO USE!" before proceeding.

### c) Configure Python Environment
Install the required Python package:
```bash
pip install -r requirements.txt
```

### d) Configure Database Connection
The Python script loads database credentials from environment variables. For the Docker container, set:

```bash
export DB_USER="SYSTEM"
export DB_PASSWORD="YourPassword123"  # Use the password from step b
export DB_DSN="localhost:1521/FREEPDB1"
```

## 2. Database Initialization

The SQL scripts in the `/sql` directory must be run in order to set up the schema, indexes, and reference data.

### Using SQLcl

Connect to your Docker database using SQLcl:

```bash
sql SYSTEM/YourPassword123@localhost:1521/FREEPDB1
```

### What These Scripts Do

The scripts build up the POC in three phases:

**Phase 1: Spatial Foundation**
- `01_setup_schema.sql` - Creates tables for restricted zones and GPS tracking events with spatial geometry columns
- `02_configure_spatial_metadata.sql` - Registers geometry columns with Oracle Spatial and creates R-tree indexes for fast queries
- `03_legacy_alert_logic.sql` - Demonstrates baseline geofencing: detects when GPS pings breach zone boundaries

**Phase 2: Vector Intelligence**
- `04_setup_vector_table.sql` - Creates table to store behavioral patterns as 3D vectors [speed, dwell_time, proximity]
- `05_seed_knowledge_base.sql` - Seeds reference patterns: "Safe Traffic Detour" vs "High Risk Loitering"

**Phase 3: Hybrid Query**
- `06_hybrid_query.sql` - Combines spatial + vector search to distinguish routine events from genuine risks

### Running the Scripts

Once connected, run the scripts in sequence:

```sql
@sql/01_setup_schema.sql
@sql/02_configure_spatial_metadata.sql
@sql/03_legacy_alert_logic.sql
@sql/04_setup_vector_table.sql
@sql/05_seed_knowledge_base.sql
@sql/06_hybrid_query.sql
```

Type `exit` to disconnect from SQLcl when finished.

*Note: Scripts 05 and 06 will produce output demonstrating the hybrid queries. You can examine or ignore this output.*

## 3. Running the Demonstration

Once the database is initialized, you can run the Python script to see the complete POC in action.

The script will simulate three scenarios:
1.  A routine event that can be safely deprioritized (driving past a school).
2.  A genuine risk event requiring officer attention (loitering near the school).
3.  An event far outside any restricted zone.

Execute the script:
```bash
python src/perimetrix_poc.py
```

### Expected Output

You should see output similar to the following:

```
Starting perimetrix POC Demonstration...
Database connection successful.
--- Analyzing Event for Parolee 101 ---
  Raw Data: Speed=45mph, Dwell=1min, Proximity=5ft
  Normalized Vector: [0.750, 0.017, 0.100]
  Best Match: 'Safe Traffic Detour' (Similarity Score: 0.0001)
  DECISION: Alert DEPRIORITIZED (Score is below threshold of 0.5)
--- Analyzing Event for Parolee 102 ---
  Raw Data: Speed=1mph, Dwell=25min, Proximity=45ft
  Normalized Vector: [0.017, 0.417, 0.900]
  Best Match: 'High Risk Loitering' (Similarity Score: 0.0139)
  DECISION: Alert TRIGGERED!
--- Analyzing Event for Parolee 103 ---
  Raw Data: Speed=60mph, Dwell=5min, Proximity=5ft
  Normalized Vector: [1.000, 0.083, 0.100]
  Result: Event is NOT within a restricted zone. No action needed.

Database connection closed.
Demonstration finished.
```
