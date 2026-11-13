"""**********************************************************************************"""
"""**********************************************************************************"""
"""
Snowflake connection helpers.

Settings come from environment variables (see .env.example). Exactly one
authentication method is used, picked in this order:

1. SNOWFLAKE_PRIVATE_KEY_FILE - key-pair authentication
2. SNOWFLAKE_TOKEN - programmatic access token (PAT)
3. SNOWFLAKE_AUTHENTICATOR - for example "externalbrowser" for SSO
4. SNOWFLAKE_PASSWORD - password
"""
"""**********************************************************************************"""
"""**********************************************************************************"""


import os
from collections.abc import Iterator
from contextlib import contextmanager
from typing import Any

REQUIRED_SETTINGS = ("SNOWFLAKE_ACCOUNT", "SNOWFLAKE_USER")
OPTIONAL_SETTINGS = {
    "SNOWFLAKE_ROLE": "role",
    "SNOWFLAKE_WAREHOUSE": "warehouse",
    "SNOWFLAKE_DATABASE": "database",
    "SNOWFLAKE_SCHEMA": "schema",
}


class SnowflakeConfigError(RuntimeError):
    """Raised when the Snowflake settings are missing or incomplete."""


def _env(name: str) -> str:
    return os.getenv(name, "").strip()


def connection_params() -> dict[str, Any]:
    missing = [name for name in REQUIRED_SETTINGS if not _env(name)]
    if missing:
        raise SnowflakeConfigError(
            f"Missing Snowflake settings in backend/.env: {', '.join(missing)}"
        )

    params: dict[str, Any] = {
        "account": _env("SNOWFLAKE_ACCOUNT"),
        "user": _env("SNOWFLAKE_USER"),
        "login_timeout": 15,
        "network_timeout": 30,
        "application": "SnowflakeIQ",
    }

    if _env("SNOWFLAKE_PRIVATE_KEY_FILE"):
        params["private_key_file"] = _env("SNOWFLAKE_PRIVATE_KEY_FILE")
        if _env("SNOWFLAKE_PRIVATE_KEY_FILE_PWD"):
            params["private_key_file_pwd"] = _env("SNOWFLAKE_PRIVATE_KEY_FILE_PWD")
    elif _env("SNOWFLAKE_TOKEN"):
        params["authenticator"] = "PROGRAMMATIC_ACCESS_TOKEN"
        params["token"] = _env("SNOWFLAKE_TOKEN")
    elif _env("SNOWFLAKE_AUTHENTICATOR").upper() == "SNOWFLAKE_JWT":
        raise SnowflakeConfigError(
            "SNOWFLAKE_AUTHENTICATOR=SNOWFLAKE_JWT is key-pair authentication, "
            "so SNOWFLAKE_PRIVATE_KEY_FILE must also be set in backend/.env."
        )
    elif _env("SNOWFLAKE_AUTHENTICATOR"):
        params["authenticator"] = _env("SNOWFLAKE_AUTHENTICATOR")
    elif _env("SNOWFLAKE_PASSWORD"):
        params["password"] = _env("SNOWFLAKE_PASSWORD")
    else:
        raise SnowflakeConfigError(
            "No Snowflake credential in backend/.env. Set one of "
            "SNOWFLAKE_PRIVATE_KEY_FILE, SNOWFLAKE_TOKEN, "
            "SNOWFLAKE_AUTHENTICATOR or SNOWFLAKE_PASSWORD."
        )

    for env_name, param_name in OPTIONAL_SETTINGS.items():
        if _env(env_name):
            params[param_name] = _env(env_name)

    return params


@contextmanager
def get_connection() -> Iterator[Any]:
    """Open a Snowflake connection and always close it afterwards."""
    # Imported here so the API still starts when the connector is not installed.
    import snowflake.connector

    connection = snowflake.connector.connect(**connection_params())
    try:
        yield connection
    finally:
        connection.close()


def fetch_session_info() -> dict[str, str | None]:
    """Run a trivial query that proves the connection and shows its context."""
    query = (
        "SELECT CURRENT_VERSION(), CURRENT_USER(), CURRENT_ROLE(), "
        "CURRENT_WAREHOUSE(), CURRENT_DATABASE(), CURRENT_SCHEMA()"
    )
    with get_connection() as connection:
        cursor = connection.cursor()
        try:
            row = cursor.execute(query).fetchone()
        finally:
            cursor.close()

    keys = ("version", "user", "role", "warehouse", "database", "schema")
    return dict(zip(keys, row))
