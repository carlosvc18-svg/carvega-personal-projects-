CREATE OR REPLACE ALERT EV_ANALYTICS.GOVERNANCE.ALERT_DQ_FAILURE
  WAREHOUSE = WH_EV_DEMO
  SCHEDULE = '30 MINUTE'
  IF (EXISTS (
    -- Check: reconciliation failures in last hour
    SELECT 1
    FROM EV_ANALYTICS.GOVERNANCE.PIPELINE_AUDIT
    WHERE overall_status IN ('FAIL', 'WARN')
      AND run_timestamp > DATEADD(hour, -1, CURRENT_TIMESTAMP())
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'EV_ANALYTICS_EMAIL',
      'carlosvegacam@outlook.es',
      'EV Pipeline Data Quality Alert',
      (SELECT 'ALERT: Data quality issue detected at ' || CURRENT_TIMESTAMP()::STRING ||
              '\n\nReconciliation Status: ' || 
              (SELECT LISTAGG(overall_status || ' — ' || notes, '\n') 
               FROM EV_ANALYTICS.GOVERNANCE.PIPELINE_AUDIT
               WHERE overall_status IN ('FAIL', 'WARN')
                 AND run_timestamp > DATEADD(hour, -1, CURRENT_TIMESTAMP())) ||
              '\n\nAction required: Check EV_ANALYTICS.GOVERNANCE.PIPELINE_AUDIT for details.')
    )