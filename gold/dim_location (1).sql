-- Gold layer location dimension keyed on county/city/state/postal_code
-- Co-authored with CoCo
CREATE OR REPLACE DYNAMIC TABLE EV_ANALYTICS.GOLD.DIM_LOCATION(
    LOCATION_KEY,
    COUNTY,
    CITY,
    STATE,
    POSTAL_CODE,
    LEGISLATIVE_DISTRICT,
    CENSUS_TRACT,
    IS_WA_REGISTRATION
) TARGET_LAG = 'DOWNSTREAM'
  REFRESH_MODE = AUTO
  INITIALIZE = ON_CREATE
  WAREHOUSE = WH_EV_DEMO
AS
SELECT
    MD5(COALESCE(county,'') || '|' || COALESCE(city,'') || '|' || COALESCE(state,'') || '|' || COALESCE(postal_code,'')) AS location_key,
    county,
    city,
    state,
    postal_code,
    MAX(legislative_district) AS legislative_district,
    MAX(census_tract) AS census_tract,
    MAX(is_wa_registration::INT)::BOOLEAN AS is_wa_registration
FROM EV_ANALYTICS.SILVER.EV_REGISTRATIONS
GROUP BY county, city, state, postal_code;
