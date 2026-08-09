# EV Pipeline Data Quality Dashboard
# Co-authored with CoCo
import os
import streamlit as st

st.set_page_config(page_title="EV Pipeline DQ", layout="wide")

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))


@st.cache_data(ttl=120)
def get_reconciliation_history():
    return conn.query("""
        SELECT audit_id, batch_id, run_timestamp, bronze_row_count,
               silver_row_count, quarantine_count, gold_fact_count,
               reconcile_bronze_silver, reconcile_silver_fact,
               overall_status, notes
        FROM EV_ANALYTICS.GOVERNANCE.PIPELINE_AUDIT
        ORDER BY run_timestamp DESC
        LIMIT 50
    """)


@st.cache_data(ttl=120)
def get_dq_metrics():
    return conn.query("""
        SELECT
            measurement_time,
            metric_database || '.' || metric_schema || '.' || metric_name AS dmf_name,
            metric_name,
            table_schema || '.' || table_name AS target_table,
            ARRAY_TO_STRING(column_names, ', ') AS columns_checked,
            value::INT AS metric_value
        FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
        WHERE table_database = 'EV_ANALYTICS'
        ORDER BY measurement_time DESC
        LIMIT 100
    """)


@st.cache_data(ttl=120)
def get_layer_counts():
    return conn.query("""
        SELECT 'BRONZE' AS layer, COUNT(*) AS row_count
        FROM EV_ANALYTICS.BRONZE.EV_RAW r,
        LATERAL FLATTEN(input => r.raw_record:data) d
        UNION ALL
        SELECT 'SILVER', COUNT(*) FROM EV_ANALYTICS.SILVER.EV_REGISTRATIONS
        UNION ALL
        SELECT 'GOLD_FACT', COUNT(*) FROM EV_ANALYTICS.GOLD.FACT_EV_REGISTRATION
    """)


st.title("EV Pipeline Data Quality")
st.caption("Monitoring reconciliation, DMF results, and pipeline health")

if st.button("Refresh data", type="primary"):
    get_reconciliation_history.clear()
    get_dq_metrics.clear()
    get_layer_counts.clear()
    st.rerun()

# --- KPI Row ---
counts_df = get_layer_counts()
counts = dict(zip(counts_df["LAYER"], counts_df["ROW_COUNT"]))

recon_df = get_reconciliation_history()
latest_status = recon_df["OVERALL_STATUS"].iloc[0] if len(recon_df) > 0 else "NO RUNS"
status_delta = "PASS" if latest_status == "PASS" else "ISSUE"

with st.container(horizontal=True):
    st.metric("Bronze Rows", f"{counts.get('BRONZE', 0):,}", border=True)
    st.metric("Silver Rows", f"{counts.get('SILVER', 0):,}", border=True)
    st.metric("Gold Fact Rows", f"{counts.get('GOLD_FACT', 0):,}", border=True)
    st.metric(
        "Last Reconciliation",
        latest_status,
        status_delta,
        delta_color="normal" if latest_status == "PASS" else "inverse",
        border=True,
    )

# --- Reconciliation History ---
with st.container(border=True):
    st.subheader("Reconciliation History")
    if len(recon_df) > 0:
        st.dataframe(
            recon_df,
            hide_index=True,
            column_config={
                "OVERALL_STATUS": st.column_config.TextColumn("Status", width="small"),
                "RECONCILE_BRONZE_SILVER": st.column_config.CheckboxColumn("Bronze=Silver"),
                "RECONCILE_SILVER_FACT": st.column_config.CheckboxColumn("Silver=Fact"),
            },
        )
    else:
        st.info("No reconciliation runs yet. Call SP_RECONCILE to generate data.")

# --- DMF Results ---
with st.container(border=True):
    st.subheader("Data Metric Function Results")
    st.caption("From SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS")
    try:
        dq_df = get_dq_metrics()
        if len(dq_df) > 0:
            col1, col2 = st.columns(2)
            with col1:
                failing = dq_df[dq_df["METRIC_VALUE"] > 0]
                if len(failing) > 0:
                    st.error(f"{len(failing)} metric(s) with non-zero values")
                    st.dataframe(failing, hide_index=True)
                else:
                    st.success("All DMF checks passing (value = 0)")
            with col2:
                st.bar_chart(
                    dq_df.groupby("METRIC_NAME")["METRIC_VALUE"].sum().reset_index(),
                    x="METRIC_NAME",
                    y="METRIC_VALUE",
                )
        else:
            st.info("No DMF results yet. Attach DMFs and wait for a refresh cycle.")
    except Exception as e:
        st.warning(
            f"DMF results unavailable (Enterprise Edition required): {e}"
        )
        st.markdown("""
        **When DMFs are enabled, this section will show:**
        - NULL_COUNT on dol_vehicle_id, make, county
        - DUPLICATE_COUNT on dol_vehicle_id
        - ROW_COUNT on the table
        - FRESHNESS on ingested_at (60-min threshold)
        - Custom: INVALID_RANGE_COUNT, INVALID_MODEL_YEAR_COUNT, ORPHAN_FACT_COUNT
        """)

# --- Pipeline DAG Status ---
with st.container(border=True):
    st.subheader("Dynamic Table Refresh Status")
    try:
        dt_status = conn.query("""
            SHOW DYNAMIC TABLES IN DATABASE EV_ANALYTICS
        """)
        st.dataframe(
            dt_status[["name", "schema_name", "target_lag", "refresh_mode", "scheduling_state", "data_timestamp"]],
            hide_index=True,
        )
    except Exception as e:
        st.error(f"Could not load DT status: {e}")
