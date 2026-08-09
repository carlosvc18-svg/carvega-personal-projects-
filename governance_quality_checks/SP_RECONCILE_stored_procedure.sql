CREATE OR REPLACE PROCEDURE EV_ANALYTICS.GOVERNANCE.SP_RECONCILE(P_BATCH_ID STRING)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    LET v_bronze_rows NUMBER := 0;
    LET v_bronze_unique NUMBER := 0;
    LET v_silver_rows NUMBER := 0;
    LET v_quarantine NUMBER := 0;
    LET v_gold_fact NUMBER := 0;
    LET v_reconcile_bs BOOLEAN := FALSE;
    LET v_reconcile_sf BOOLEAN := FALSE;
    LET v_status STRING := '';
    LET v_notes STRING := '';

    -- Bronze: total rows in the data array (flattened count)
    SELECT COUNT(*)
    INTO :v_bronze_rows
    FROM EV_ANALYTICS.BRONZE.EV_RAW r,
    LATERAL FLATTEN(input => r.raw_record:data) d;

    -- Bronze unique (deduplicated by dol_vehicle_id, same logic as Silver)
    SELECT COUNT(DISTINCT d.value[21]::STRING)
    INTO :v_bronze_unique
    FROM EV_ANALYTICS.BRONZE.EV_RAW r,
    LATERAL FLATTEN(input => r.raw_record:data) d;

    -- Silver: current row count
    SELECT COUNT(*)
    INTO :v_silver_rows
    FROM EV_ANALYTICS.SILVER.EV_REGISTRATIONS;

    -- Quarantine: bronze dupes that Silver's QUALIFY removed
    v_quarantine := v_bronze_rows - v_bronze_unique;

    -- Gold fact: row count
    SELECT COUNT(*)
    INTO :v_gold_fact
    FROM EV_ANALYTICS.GOLD.FACT_EV_REGISTRATION;

    -- Reconciliation 1: bronze_unique = silver (after dedupe)
    v_reconcile_bs := (v_bronze_unique = v_silver_rows);

    -- Reconciliation 2: silver = gold fact (1:1 mapping, no filter)
    v_reconcile_sf := (v_silver_rows = v_gold_fact);

    -- Overall status
    IF (v_reconcile_bs AND v_reconcile_sf) THEN
        v_status := 'PASS';
        v_notes := 'All reconciliations passed.';
    ELSEIF (NOT v_reconcile_bs AND NOT v_reconcile_sf) THEN
        v_status := 'FAIL';
        v_notes := 'Both reconciliations failed. Bronze→Silver gap: ' || 
                   (v_bronze_unique - v_silver_rows)::STRING || 
                   '. Silver→Fact gap: ' || (v_silver_rows - v_gold_fact)::STRING;
    ELSEIF (NOT v_reconcile_bs) THEN
        v_status := 'WARN';
        v_notes := 'Bronze→Silver mismatch. Gap: ' || (v_bronze_unique - v_silver_rows)::STRING ||
                   ' rows. Possible refresh lag.';
    ELSE
        v_status := 'WARN';
        v_notes := 'Silver→Fact mismatch. Gap: ' || (v_silver_rows - v_gold_fact)::STRING ||
                   ' rows. Fact DT may be refreshing.';
    END IF;

    -- Log the audit record
    INSERT INTO EV_ANALYTICS.GOVERNANCE.PIPELINE_AUDIT (
        batch_id, bronze_row_count, silver_row_count, quarantine_count,
        gold_fact_count, bronze_minus_dupes, reconcile_bronze_silver,
        reconcile_silver_fact, overall_status, notes
    )
    VALUES (
        :P_BATCH_ID, :v_bronze_rows, :v_silver_rows, :v_quarantine,
        :v_gold_fact, :v_bronze_unique, :v_reconcile_bs,
        :v_reconcile_sf, :v_status, :v_notes
    );

    RETURN v_status || ': ' || v_notes;
END