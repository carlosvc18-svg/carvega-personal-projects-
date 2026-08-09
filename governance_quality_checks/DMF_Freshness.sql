-- Attach FRESHNESS DMF with 60-minute threshold
ALTER DYNAMIC TABLE EV_ANALYTICS.SILVER.EV_REGISTRATIONS
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON (ingested_at);

-- Query freshness results
SELECT
    measurement_time,
    value::INT AS staleness_seconds,
    CASE WHEN value > 3600 THEN 'STALE (>60 min)' ELSE 'FRESH' END AS status
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE metric_name = 'FRESHNESS'
  AND table_name = 'EV_REGISTRATIONS'
ORDER BY measurement_time DESC;