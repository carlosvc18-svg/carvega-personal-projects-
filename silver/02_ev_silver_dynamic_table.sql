EV_ANALYTICS.PUBLIC."carvega-personal-projects-"create or replace dynamic table EV_ANALYTICS.SILVER.EV_REGISTRATIONS(
	DOL_VEHICLE_ID,
	VIN_PREFIX,
	COUNTY,
	CITY,
	STATE,
	POSTAL_CODE,
	MODEL_YEAR,
	MAKE,
	MODEL,
	EV_TYPE,
	CAFV_ELIGIBILITY,
	ELECTRIC_RANGE,
	BASE_MSRP,
	LEGISLATIVE_DISTRICT,
	VEHICLE_LOCATION,
	ELECTRIC_UTILITY,
	CENSUS_TRACT,
	RANGE_IS_RESEARCHED,
	IS_WA_REGISTRATION,
	INGESTED_AT
) target_lag = '10 minutes' refresh_mode = INCREMENTAL initialize = ON_CREATE warehouse = WH_EV_DEMO
 as
WITH exploded AS (
  SELECT
    d.value                                AS row_arr,
    r.ingested_at
  FROM EV_ANALYTICS.BRONZE.EV_RAW r,
  LATERAL FLATTEN(input => r.raw_record:data) d
)
SELECT
    row_arr[21]::STRING                                         AS dol_vehicle_id,
    row_arr[8]::STRING                                          AS vin_prefix,
    row_arr[9]::STRING                                          AS county,
    row_arr[10]::STRING                                         AS city,
    row_arr[11]::STRING                                         AS state,
    row_arr[12]::STRING                                         AS postal_code,
    row_arr[13]::INT                                            AS model_year,
    UPPER(TRIM(row_arr[14]::STRING))                            AS make,
    row_arr[15]::STRING                                         AS model,
    row_arr[16]::STRING                                         AS ev_type,
    row_arr[17]::STRING                                         AS cafv_eligibility,
    row_arr[18]::INT                                            AS electric_range,
    NULLIF(row_arr[19]::NUMBER, 0)                              AS base_msrp,
    row_arr[20]::INT                                            AS legislative_district,
    TRY_TO_GEOGRAPHY(row_arr[22]::STRING)                       AS vehicle_location,
    row_arr[23]::STRING                                         AS electric_utility,
    row_arr[24]::STRING                                         AS census_tract,
    (row_arr[17]::STRING NOT ILIKE '%not been researched%')     AS range_is_researched,
    (row_arr[11]::STRING = 'WA')                                AS is_wa_registration,
    ingested_at
FROM exploded
QUALIFY ROW_NUMBER() OVER (PARTITION BY row_arr[21]::STRING ORDER BY ingested_at DESC) = 1;