-- ════════════════════════════════════════════════════════════
-- DMF 1: INVALID_RANGE_COUNT
-- Rows claiming range is researched but range is ≤ 0
-- Attach to: SILVER.EV_REGISTRATIONS (range_is_researched, electric_range)
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE DATA METRIC FUNCTION EV_ANALYTICS.GOVERNANCE.INVALID_RANGE_COUNT(
  ARG_T TABLE(range_is_researched BOOLEAN, electric_range INT)
)
RETURNS NUMBER
AS
$$
  SELECT COUNT(*)
  FROM ARG_T
  WHERE range_is_researched = TRUE AND electric_range <= 0
$$;

-- ════════════════════════════════════════════════════════════
-- DMF 2: INVALID_MODEL_YEAR_COUNT
-- Model years outside the plausible window 1990..current+2
-- Attach to: SILVER.EV_REGISTRATIONS (model_year)
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE DATA METRIC FUNCTION EV_ANALYTICS.GOVERNANCE.INVALID_MODEL_YEAR_COUNT(
  ARG_T TABLE(model_year INT)
)
RETURNS NUMBER
AS
$$
  SELECT COUNT(*)
  FROM ARG_T
  WHERE model_year < 1990 OR model_year > EXTRACT(YEAR FROM CURRENT_DATE()) + 2
$$;

-- ════════════════════════════════════════════════════════════
-- DMF 3: ORPHAN_FACT_COUNT
-- Fact rows with no matching dimension (referential integrity)
-- Attach to: GOLD.FACT_EV_REGISTRATION (vehicle_key)
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE DATA METRIC FUNCTION EV_ANALYTICS.GOVERNANCE.ORPHAN_FACT_COUNT(
  ARG_T TABLE(vehicle_key VARCHAR)
)
RETURNS NUMBER
AS
$$
  SELECT COUNT(*)
  FROM ARG_T f
  WHERE f.vehicle_key NOT IN (
    SELECT d.vehicle_key FROM EV_ANALYTICS.GOLD.DIM_VEHICLE d
  )
$$;