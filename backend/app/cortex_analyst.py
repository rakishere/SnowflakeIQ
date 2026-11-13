"""**********************************************************************************"""
"""**********************************************************************************"""
"""
Natural-language querying through Snowflake Cortex Analyst.

A question is sent to the Cortex Analyst REST API together with the semantic
view named in SNOWFLAKE_SEMANTIC_VIEW. Cortex Analyst answers with an
explanation and, when it can, a SQL statement. That statement is then run on
the same connection and the rows are returned with the answer.
"""
"""**********************************************************************************"""
"""**********************************************************************************"""

import os
import re
from typing import Any

import requests

from app.snowflake_client import SnowflakeConfigError, get_connection

ANALYST_PATH = "/api/v2/cortex/analyst/message"
ANALYST_TIMEOUT_SECONDS = 120
MAX_ROWS = 200

_LEADING_COMMENTS = re.compile(r"^(\s*(--[^\n]*\n|/\*.*?\*/))*\s*", re.DOTALL)


class AnalystError(RuntimeError):
    """Raised when Cortex Analyst rejects or cannot process a request."""


def semantic_view_name() -> str:
    name = os.getenv("SNOWFLAKE_SEMANTIC_VIEW", "").strip()
    if not name:
        raise SnowflakeConfigError(
            "Missing SNOWFLAKE_SEMANTIC_VIEW in backend/.env "
            "(use the full name: DATABASE.SCHEMA.VIEW)"
        )
    return name


def _call_analyst(connection: Any, messages: list[dict[str, Any]]) -> dict[str, Any]:
    """Send the conversation to Cortex Analyst using the session's token."""
    response = requests.post(
        f"https://{connection.host}{ANALYST_PATH}",
        headers={
            "Authorization": f'Snowflake Token="{connection.rest.token}"',
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        json={"messages": messages, "semantic_view": semantic_view_name()},
        timeout=ANALYST_TIMEOUT_SECONDS,
    )
    try:
        body = response.json()
    except ValueError:
        body = None

    if response.status_code != 200 or not isinstance(body, dict):
        if isinstance(body, dict):
            detail = body.get("message") or body
        else:
            detail = body or response.text[:300] or "no details returned"
        raise AnalystError(
            f"Cortex Analyst returned HTTP {response.status_code}: {detail}"
        )
    return body


def _is_read_only(statement: str) -> bool:
    body = _LEADING_COMMENTS.sub("", statement, count=1).lower()
    return body.startswith(("select", "with"))


def _run_sql(connection: Any, statement: str) -> dict[str, Any]:
    if not _is_read_only(statement):
        raise AnalystError("Generated statement is not a read-only query")

    cursor = connection.cursor()
    try:
        cursor.execute(statement)
        columns = [column[0] for column in cursor.description]
        rows = cursor.fetchmany(MAX_ROWS + 1)
    finally:
        cursor.close()

    return {
        "columns": columns,
        "rows": [list(row) for row in rows[:MAX_ROWS]],
        "truncated": len(rows) > MAX_ROWS,
    }


def ask(question: str, history: list[dict[str, Any]]) -> dict[str, Any]:
    """Answer a question, given the earlier messages of the conversation."""
    messages = [
        *history,
        {"role": "user", "content": [{"type": "text", "text": question}]},
    ]

    with get_connection() as connection:
        body = _call_analyst(connection, messages)
        message = body.get("message") or {}
        content = message.get("content") or []

        text = "\n\n".join(
            item.get("text", "") for item in content if item.get("type") == "text"
        )
        sql = next(
            (item.get("statement") for item in content if item.get("type") == "sql"),
            None,
        )
        suggestions = [
            suggestion
            for item in content
            if item.get("type") == "suggestions"
            for suggestion in item.get("suggestions", [])
        ]

        result: dict[str, Any] | None = None
        sql_error: str | None = None
        if sql:
            try:
                result = _run_sql(connection, sql)
            except Exception as error:
                sql_error = str(error)

    return {
        "text": text,
        "sql": sql,
        "suggestions": suggestions,
        "columns": result["columns"] if result else [],
        "rows": result["rows"] if result else [],
        "truncated": result["truncated"] if result else False,
        "sql_error": sql_error,
        # Sent back by the client as history so follow-up questions keep context.
        "message": {"role": "analyst", "content": content},
        "request_id": body.get("request_id"),
    }
