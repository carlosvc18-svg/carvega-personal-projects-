-- Gold layer vehicle dimension with EV_TYPE included in hash key to prevent fan-out
-- Co-authored with CoCo
CREATE OR REPLACE DYNAMIC TABLE EV_ANALYTICS.GOLD.DIM_VEHICLE(
    VEHICLE_KEY,
    MAKE,
    MODEL,
    MODEL_YEAR,
    EV_TYPE,
    CAFV_ELIGIBILITY,
    ELECTRIC_RANGE,
    RANGE_IS_RESEARCHED
) TARGET_LAG = 'DOWNSTREAM'
  REFRESH_MODE = AUTO
  INITIALIZE = ON_CREATE
  WAREHOUSE = WH_EV_DEMO
AS
SELECT
    MD5(COALESCE(make,'') || '|' || COALESCE(model,'') || '|' || COALESCE(model_year::STRING,'') || '|' || COALESCE(ev_type,'') || '|' || COALESCE(cafv_eligibility,'')) AS vehicle_key,
    make,
    model,
    model_year,
    ev_type,
    cafv_eligibility,
    MAX(electric_range) AS electric_range,
    MAX(range_is_researched::INT)::BOOLEAN AS range_is_researched
FROM EV_ANALYTICS.SILVER.EV_REGISTRATIONS
GROUP BY make, model, model_year, ev_type, cafv_eligibility;
