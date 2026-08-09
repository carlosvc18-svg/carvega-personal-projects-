# EV Insights dashboard reading Gold aggregate tables for cost-efficient analytics
# Co-authored with CoCo
import os
import streamlit as st

st.set_page_config(page_title="EV Insights", layout="wide")

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))


@st.cache_data(ttl=300)
def get_registrations_by_year_make():
    return conn.query("""
        SELECT model_year, make, ev_type, registration_count, avg_range_miles, pct_of_year
        FROM EV_ANALYTICS.GOLD.AGG_REGISTRATIONS_BY_YEAR_MAKE
        ORDER BY model_year, registration_count DESC
    """)


@st.cache_data(ttl=300)
def get_adoption_by_county():
    return conn.query("""
        SELECT county, registration_count, unique_makes, unique_models,
               earliest_year, latest_year, county_rank
        FROM EV_ANALYTICS.GOLD.AGG_ADOPTION_BY_COUNTY
        ORDER BY county_rank
    """)


@st.cache_data(ttl=300)
def get_ev_type_share():
    return conn.query("""
        SELECT county, ev_type, registration_count, pct_of_county
        FROM EV_ANALYTICS.GOLD.AGG_EV_TYPE_SHARE_BY_COUNTY
        ORDER BY county, ev_type
    """)


st.title("WA Electric Vehicle Insights")
st.caption("All queries hit pre-aggregated Gold tables — zero full-table scans")

if st.button("Refresh data"):
    get_registrations_by_year_make.clear()
    get_adoption_by_county.clear()
    get_ev_type_share.clear()
    st.rerun()

# Load data
reg_df = get_registrations_by_year_make()
adoption_df = get_adoption_by_county()
ev_share_df = get_ev_type_share()

# --- KPI Metrics ---
total_registrations = int(adoption_df["REGISTRATION_COUNT"].sum())
total_counties = len(adoption_df)
total_makes = int(reg_df["MAKE"].nunique())
top_county = adoption_df.iloc[0]["COUNTY"] if len(adoption_df) > 0 else "N/A"

with st.container(horizontal=True):
    st.metric("Total WA Registrations", f"{total_registrations:,}", border=True)
    st.metric("Counties with EVs", total_counties, border=True)
    st.metric("Manufacturers", total_makes, border=True)
    st.metric("Top County", top_county, border=True)

# --- Tabs ---
tab1, tab2, tab3 = st.tabs([
    "Market Share by Make",
    "BEV vs PHEV by Year",
    "Electric Range Analysis",
])

# === TAB 1: Market share by make with county filter ===
with tab1:
    st.subheader("Market Share by Manufacturer")

    counties = sorted(ev_share_df["COUNTY"].unique())
    selected_county = st.selectbox("Filter by county", ["All Counties"] + counties, key="tab1_county")

    if selected_county == "All Counties":
        make_data = reg_df.groupby("MAKE", as_index=False)["REGISTRATION_COUNT"].sum()
    else:
        county_total = adoption_df[adoption_df["COUNTY"] == selected_county]["REGISTRATION_COUNT"].values
        st.info(f"{selected_county} has {int(county_total[0]):,} total EV registrations" if len(county_total) > 0 else "")
        county_share = ev_share_df[ev_share_df["COUNTY"] == selected_county]
        make_data = county_share.rename(columns={"EV_TYPE": "MAKE", "REGISTRATION_COUNT": "REGISTRATION_COUNT"})

    make_data_sorted = make_data.sort_values("REGISTRATION_COUNT", ascending=False).head(15)
    st.bar_chart(make_data_sorted, x="MAKE", y="REGISTRATION_COUNT", horizontal=True)

    if selected_county == "All Counties":
        st.dataframe(
            reg_df.groupby("MAKE", as_index=False).agg(
                REGISTRATIONS=("REGISTRATION_COUNT", "sum"),
                AVG_RANGE=("AVG_RANGE_MILES", "mean"),
            ).sort_values("REGISTRATIONS", ascending=False),
            hide_index=True,
        )

# === TAB 2: BEV vs PHEV stacked by model year ===
with tab2:
    st.subheader("BEV vs PHEV Registrations by Model Year")

    year_type = reg_df.groupby(["MODEL_YEAR", "EV_TYPE"], as_index=False)["REGISTRATION_COUNT"].sum()
    pivot = year_type.pivot(index="MODEL_YEAR", columns="EV_TYPE", values="REGISTRATION_COUNT").fillna(0)
    pivot = pivot.sort_index()

    bev_total = int(year_type[year_type["EV_TYPE"].str.contains("BEV")]["REGISTRATION_COUNT"].sum())
    phev_total = int(year_type[year_type["EV_TYPE"].str.contains("PHEV")]["REGISTRATION_COUNT"].sum())
    bev_pct = round(100 * bev_total / (bev_total + phev_total), 1)

    col1, col2, col3 = st.columns(3)
    col1.metric("BEV Registrations", f"{bev_total:,}", border=True)
    col2.metric("PHEV Registrations", f"{phev_total:,}", border=True)
    col3.metric("BEV Share", f"{bev_pct}%", border=True)

    st.bar_chart(pivot)

# === TAB 3: Average electric range with exclusion callout ===
with tab3:
    st.subheader("Average Electric Range by Model Year")

    researched = reg_df[reg_df["AVG_RANGE_MILES"].notna() & (reg_df["AVG_RANGE_MILES"] > 0)]
    not_researched = reg_df[reg_df["AVG_RANGE_MILES"].isna() | (reg_df["AVG_RANGE_MILES"] == 0)]

    excluded_rows = int(not_researched["REGISTRATION_COUNT"].sum())
    included_rows = int(researched["REGISTRATION_COUNT"].sum())
    exclusion_pct = round(100 * excluded_rows / (excluded_rows + included_rows), 1) if (excluded_rows + included_rows) > 0 else 0

    col1, col2 = st.columns(2)
    with col1:
        st.metric("Vehicles with Known Range", f"{included_rows:,}", border=True)
    with col2:
        st.metric(
            "Excluded (range not researched)",
            f"{excluded_rows:,} ({exclusion_pct}%)",
            border=True,
        )

    with st.container(border=True):
        st.caption(
            "Excluded rows have electric_range = 0 because the DOL has not yet "
            "researched battery range for these vehicles (primarily 2021+ model years). "
            "CAFV eligibility shows 'unknown as battery range has not been researched'. "
            "These are NOT zero-range vehicles — they are data gaps."
        )

    range_by_year = researched.groupby("MODEL_YEAR", as_index=False).apply(
        lambda g: g.assign(
            WEIGHTED_RANGE=g["AVG_RANGE_MILES"] * g["REGISTRATION_COUNT"]
        )
    ).groupby("MODEL_YEAR", as_index=False).agg(
        TOTAL_WEIGHTED=("WEIGHTED_RANGE", "sum"),
        TOTAL_COUNT=("REGISTRATION_COUNT", "sum"),
    )
    range_by_year["AVG_RANGE"] = (range_by_year["TOTAL_WEIGHTED"] / range_by_year["TOTAL_COUNT"]).round(1)
    range_by_year = range_by_year.sort_values("MODEL_YEAR")

    st.line_chart(range_by_year, x="MODEL_YEAR", y="AVG_RANGE")

# --- Cost explanation ---
with st.expander("Why AGG_* tables instead of FACT_EV_REGISTRATION?"):
    st.markdown("""
**Warehouse cost is proportional to data scanned.**

| Approach | Table | Rows Scanned | Micro-partitions |
|----------|-------|-------------|-----------------|
| AGG tables (this app) | AGG_ADOPTION_BY_COUNTY | **38 rows** | 1 |
| AGG tables (this app) | AGG_REGISTRATIONS_BY_YEAR_MAKE | **254 rows** | 1 |
| AGG tables (this app) | AGG_EV_TYPE_SHARE_BY_COUNTY | **74 rows** | 1 |
| Fact table (naive) | FACT_EV_REGISTRATION | **22,183 rows** | ~20+ partitions |

**Impact at scale:**
- Every dashboard refresh re-executes queries. With 10 users refreshing 5x/day,
  that's 50 queries/day.
- Scanning 22K rows (growing to 200K+) with GROUP BY per query = warehouse active
  for seconds per query × credit cost.
- Scanning 38–254 pre-aggregated rows = warehouse active for milliseconds. Queries
  finish in the warehouse's auto-resume window without extending active time.

**The Dynamic Table pattern pays for aggregation ONCE** (at refresh time, on schedule),
then every dashboard read is effectively free — hitting tiny, pre-computed tables
that fit in a single micro-partition and benefit from result caching.
    """)
