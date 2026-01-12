# Sentinel - Intelligent Geospatial Monitoring POC

This project is a Proof of Concept (POC) for an intelligent geospatial monitoring system.

It uses **Oracle Database 23ai** to unlock the contextual intelligence potential of traditional geospatial monitoring systems. By combining native Spatial capabilities with **AI Vector Search**, the system enhances existing geofencing with behavioral context, enabling it to distinguish between routine events (like a user driving through a restricted zone) and genuine risk behaviors (like loitering in one). This optimization helps buffer officers from false positives while elevating true threats from the noise.

## Prerequisites

- Python 3.8+
- Access to an Oracle Database 23ai instance (the [Always Free tier](https://www.oracle.com/cloud/free/) is sufficient).
- Oracle Client libraries installed on your machine.

## 1. Setup

### a) Clone the Repository
```bash
git clone <YOUR_GITHUB_REPO_URL>
cd sentinel
```

### b) Configure Python Environment
Install the required Python package:
```bash
pip install -r requirements.txt
```

### c) Configure Database Connection
The Python script loads database credentials from environment variables to avoid hardcoding them. Set the following variables in your terminal:

```bash
export DB_USER="your_oracle_username"
export DB_PASSWORD="your_oracle_password"
export DB_DSN="your_database_connect_string"
```
The `DB_DSN` is your database's connection string (e.g., `localhost:1521/FREEPDB1`).

## 2. Database Initialization

The SQL scripts in the `/sql` directory must be run in order to set up the schema, indexes, and reference data. You can run them using a tool like SQL*Plus or SQLcl.

Connect to your database and run the scripts in the following sequence:

```
@sql/01_setup_schema.sql
@sql/02_configure_spatial_metadata.sql
@sql/03_legacy_alert_logic.sql
@sql/04_setup_vector_table.sql
@sql/05_seed_knowledge_base.sql
@sql/06_hybrid_query.sql
```
*Note: The last two scripts will produce output demonstrating the underlying queries. You can ignore or examine this as you see fit.*

## 3. Running the Demonstration

Once the database is initialized, you can run the Python script to see the complete POC in action.

The script will simulate three scenarios:
1.  A routine event that can be safely deprioritized (driving past a school).
2.  A genuine risk event requiring officer attention (loitering near the school).
3.  An event far outside any restricted zone.

Execute the script:
```bash
python src/sentinel_poc.py
```

### Expected Output

You should see output similar to the following:

```
Starting Sentinel POC Demonstration...
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
