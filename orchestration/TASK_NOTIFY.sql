create or replace task EV_ANALYTICS.GOVERNANCE.TASK_NOTIFY
	warehouse=WH_EV_DEMO
	after EV_ANALYTICS.GOVERNANCE.TASK_DQ
	as CALL SYSTEM$SEND_EMAIL(
    'EV_ANALYTICS_EMAIL',
    'carlosvegacam@outlook.es',
    'EV Pipeline DAG Complete - ' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYY-MM-DD HH24:MI'),
    (SELECT 'Pipeline run completed at ' || CURRENT_TIMESTAMP()::STRING ||
            '\n\nLatest reconciliation:\n' ||
            '  Status: ' || overall_status ||
            '\n  Bronze: ' || bronze_row_count::STRING ||
            '\n  Silver: ' || silver_row_count::STRING ||
            '\n  Quarantine: ' || quarantine_count::STRING ||
            '\n  Gold Fact: ' || gold_fact_count::STRING ||
            '\n  Notes: ' || COALESCE(notes, 'N/A')
     FROM EV_ANALYTICS.GOVERNANCE.PIPELINE_AUDIT
     ORDER BY run_timestamp DESC LIMIT 1)
  );