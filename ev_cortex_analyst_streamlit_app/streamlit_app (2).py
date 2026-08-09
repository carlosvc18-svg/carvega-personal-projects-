# Chat with EV data via Cortex Analyst using the deployed EV_REGISTRATION_ANALYTICS semantic view
# Co-authored with CoCo
import os
import json
import requests
import streamlit as st

st.set_page_config(page_title="EV Analyst Chat", layout="wide")
st.title("EV Registration Analyst")
st.caption("Chat with WA electric vehicle data using natural language")

SEMANTIC_VIEW_FQN = "EV_ANALYTICS.SEMANTIC.EV_REGISTRATION_ANALYTICS"

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
session = conn.session()


def _get_host():
    """Get the Snowflake account host for REST API calls."""
    host = os.environ.get("SNOWFLAKE_HOST")
    if host:
        return host
    row = session.sql(
        "SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() AS acct"
    ).collect()
    return f"{row[0]['ACCT']}.snowflakecomputing.com"


def _get_token():
    """Read the OAuth session token from the container runtime."""
    token_path = os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")
    with open(token_path) as f:
        return f.read().strip()

SUGGESTIONS = {
    "YoY growth": "What is the year-over-year growth trend in EV registrations?",
    "Top counties": "Which counties have the most EV registrations?",
    "BEV vs PHEV": "What is the BEV vs PHEV breakdown?",
    "Tesla share": "What is Tesla market share by county?",
    "CAFV eligibility": "What percentage of vehicles are CAFV eligible?",
    "Range by year": "What is the average electric range by model year for researched vehicles?",
}

if "messages" not in st.session_state:
    st.session_state.messages = []
if "analyst_messages" not in st.session_state:
    st.session_state.analyst_messages = []


def call_analyst(user_question: str) -> dict:
    """Call Cortex Analyst via REST API with OAuth token auth."""
    st.session_state.analyst_messages.append({
        "role": "user",
        "content": [{"type": "text", "text": user_question}],
    })

    request_body = {
        "messages": st.session_state.analyst_messages,
        "semantic_view": SEMANTIC_VIEW_FQN,
    }

    try:
        host = _get_host()
        token = _get_token()
        resp = requests.post(
            f"https://{host}/api/v2/cortex/analyst/message",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
                "X-Snowflake-Authorization-Token-Type": "OAUTH",
            },
            json=request_body,
            timeout=30,
        )
        resp.raise_for_status()
        resp_body = resp.json()
        message = resp_body.get("message", {})
        if not message:
            message = {"role": "assistant", "content": [{"type": "text", "text": "No response from Analyst."}]}
        result = {"message": message}
    except Exception as e:
        result = {
            "message": {
                "role": "assistant",
                "content": [{"type": "text", "text": f"Error: {e}"}],
            }
        }

    st.session_state.analyst_messages.append(result.get("message", {}))
    return result


def get_sql(result: dict) -> str | None:
    for block in result.get("message", {}).get("content", []):
        if block.get("type") == "sql":
            return block.get("statement", "")
    return None


def get_text(result: dict) -> str:
    parts = []
    for block in result.get("message", {}).get("content", []):
        if block.get("type") == "text":
            parts.append(block.get("text", ""))
    return "\n".join(parts) or ""


def auto_chart(df):
    """Auto-select chart type based on column types."""
    if df.empty or len(df.columns) < 2:
        return
    x_col = df.columns[0]
    y_cols = [c for c in df.columns[1:] if df[c].dtype in ("int64", "float64", "int32", "float32")]
    if not y_cols:
        return
    if "YEAR" in x_col.upper():
        st.line_chart(df, x=x_col, y=y_cols)
    elif df[x_col].dtype == "object" and len(df) <= 30:
        st.bar_chart(df, x=x_col, y=y_cols, horizontal=(len(df) > 10))


# --- Render chat history ---
for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        st.markdown(msg["content"])
        if msg.get("sql"):
            with st.expander("Generated SQL", expanded=False):
                st.code(msg["sql"], language="sql")
        if msg.get("dataframe") is not None:
            st.dataframe(msg["dataframe"], hide_index=True)

# --- Suggestion pills on empty chat ---
if not st.session_state.messages:
    sel = st.pills("Try asking:", list(SUGGESTIONS.keys()), label_visibility="collapsed")
    if sel:
        st.session_state.messages.append({"role": "user", "content": SUGGESTIONS[sel]})
        st.rerun()

# --- Chat input ---
if prompt := st.chat_input("Ask about EV registrations..."):
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        with st.spinner("Analyzing..."):
            result = call_analyst(prompt)

        text = get_text(result)
        sql = get_sql(result)
        st.markdown(text)

        msg_data = {"role": "assistant", "content": text, "sql": sql, "dataframe": None}

        if sql:
            with st.expander("Generated SQL", expanded=False):
                st.code(sql, language="sql")
            try:
                df = conn.query(sql)
                msg_data["dataframe"] = df
                if not df.empty:
                    st.dataframe(df, hide_index=True)
                    auto_chart(df)
                else:
                    st.info("No rows returned.")
            except Exception as e:
                st.error(f"Query failed: {e}")

        st.session_state.messages.append(msg_data)

# --- Sidebar ---
with st.sidebar:
    st.markdown("### EV Analyst Chat")
    st.caption(f"Semantic Model: `{SEMANTIC_VIEW_FQN}`")
    st.caption(f"Turns: {len(st.session_state.messages) // 2}")
    if st.button("Clear chat"):
        st.session_state.messages = []
        st.session_state.analyst_messages = []
        st.rerun()
    st.divider()
    st.markdown("**Architecture:**")
    st.markdown(
        "The app points at the semantic model "
        "`EV_REGISTRATION_ANALYTICS` which maps to:\n"
        "- **GOLD.FACT_EV_REGISTRATION** — grain (one row per vehicle)\n"
        "- **GOLD.DIM_VEHICLE** — make, model, ev_type, range\n"
        "- **GOLD.DIM_LOCATION** — county, city, state\n"
        "- **GOLD.DIM_UTILITY** — utility/renewable cuts"
    )
    st.markdown("**Multi-turn:** Follow-up questions carry context.")
