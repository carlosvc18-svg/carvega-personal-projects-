-- Gold layer fact table: one row per EV registration with surrogate keys
-- Co-authored with CoCo
CREATE OR REPLACE DYNAMIC TABLE EV_ANALYTICS.GOLD.FACT_EV_REGISTRATION(
    REGISTRATION_KEY,
    DOL_VEHICLE_ID,
    VIN_PREFIX,
    VEHICLE_KEY,
    LOCATION_KEY,
    UTILITY_KEY,
    MODEL_YEAR,
    BASE_MSRP,
    VEHICLE_LOCATION,
    INGESTED_AT
) TARGET_LAG = '10 minutes'
  REFRESH_MODE = AUTO
  INITIALIZE = ON_CREATE
  WAREHOUSE = WH_EV_DEMO
AS
SELECT
    MD5(dol_vehicle_id) AS registration_key,
    dol_vehicle_id,
    vin_prefix,
    MD5(COALESCE(make,'') || '|' || COALESCE(model,'') || '|' || COALESCE(model_year::STRING,'') || '|' || COALESCE(ev_type,'') || '|' || COALESCE(cafv_eligibility,'')) AS vehicle_key,
    MD5(COALESCE(county,'') || '|' || COALESCE(city,'') || '|' || COALESCE(state,'') || '|' || COALESCE(postal_code,'')) AS location_key,
    MD5(COALESCE(electric_utility,'')) AS utility_key,
    model_year,
    base_msrp,
    vehicle_location,
    ingested_at
FROM EV_ANALYTICS.SILVER.EV_REGISTRATIONS;
