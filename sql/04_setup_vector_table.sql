-- Phase 2, Step 4: Design the Vector Embeddings Table
-- Creates the table to store our library of "reference behaviors" as vectors.

-- This table requires Oracle Database 23ai or later.
CREATE TABLE behavior_patterns (
    pattern_id NUMBER PRIMARY KEY,
    description VARCHAR2(100),
    -- Using a 3-dimension vector for this PoC.
    -- The dimensions represent normalized values for:
    -- [Speed, Duration_in_Zone, Distance_to_Road_Centerline]
    behavior_vector VECTOR(3, FLOAT32)
);

COMMIT;

-- Verification:
-- DESCRIBE behavior_patterns;
-- Expected: The table structure should be displayed, including the 'VECTOR' datatype.
