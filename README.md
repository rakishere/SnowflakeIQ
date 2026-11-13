# SnowflakeIQ

A chat app that answers plain-English questions about sales data. It is built on
a Snowflake semantic view and Snowflake Cortex Analyst, with a React frontend
and a Python FastAPI backend.

Ask "What is the open pipeline by stage?" and get a short explanation, a result
table and the SQL that produced it.

This is a learning project. It runs locally and is not hardened for production
(see Limitations).

## How it works

1. The React page sends the question and the conversation so far to the backend.
2. The backend signs in to Snowflake as a service user and sends the question
   to Cortex Analyst together with the name of the semantic view.
3. Cortex Analyst uses the semantic view's dimensions and metrics to write SQL.
4. The backend checks that the SQL is read-only, runs it, and returns the
   explanation, the SQL, the rows and suggested follow-up questions.

The browser never talks to Snowflake and never holds Snowflake credentials.

## Project layout

- `frontend/` - React, TypeScript, Vite and Tailwind CSS chat interface.
- `backend/` - FastAPI app. `app/main.py` has the routes, `app/cortex_analyst.py`
  calls Cortex Analyst and runs the SQL, `app/snowflake_client.py` opens the
  Snowflake connection.
- `sql/Snowflake_queries.sql` - the Snowflake statements used while building the
  project: database, tables, sample data, semantic view, MCP server, service
  user, role and grants. It is a working log, not a script to run top to bottom.

## Semantic view

The view `SV_SALES_ANALYTICS` covers four tables: `CLIENTS`, `OPPORTUNITIES`,
`REVENUE` and `RISKS`. Opportunities reference clients, and revenue and risks
reference opportunities.

- Dimensions include client name, industry, opportunity name, stage, owner,
  close date (also by month, quarter and year), risk level and risk description.
- Metrics include total pipeline, open pipeline, won amount, average deal size,
  opportunity count, win rate, total revenue, revenue-to-pipeline ratio, risk
  count and high-risk count.
- Synonyms such as "deals" for opportunities and "sales rep" for owner let
  people ask in their own words.

## Prerequisites

- Node.js 20.19+ (or 22.12+) and npm
- Python 3.10+
- A Snowflake account with Cortex Analyst available

## Snowflake setup

Using `sql/Snowflake_queries.sql` as a reference:

1. Create the database, schema, tables and sample data.
2. Create the semantic view (the last `CREATE OR REPLACE SEMANTIC VIEW`
   statement in the file is the current one).
3. Create a service user and a role, and grant the role `USAGE` on the
   database, schema and warehouse, `SELECT` on the tables, and `SELECT` and
   `REFERENCES` on the semantic view.
4. Generate an RSA key pair and register the public key on the service user
   with `ALTER USER ... SET RSA_PUBLIC_KEY`. Keep the private key outside this
   repository.

## Configure and run

Open two PowerShell terminals from the project root.

### Backend

```powershell
cd backend
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
python -m uvicorn app.main:app --reload --port 8000
```

Fill in `backend/.env` before starting:

- `SNOWFLAKE_ACCOUNT` - account identifier in `orgname-accountname` form.
- `SNOWFLAKE_USER` - the service user's login name.
- `SNOWFLAKE_PRIVATE_KEY_FILE` - path to the private key (`.p8`) file.
- `SNOWFLAKE_ROLE`, `SNOWFLAKE_WAREHOUSE`, `SNOWFLAKE_DATABASE`,
  `SNOWFLAKE_SCHEMA` - session context.
- `SNOWFLAKE_SEMANTIC_VIEW` - full name of the semantic view
  (`DATABASE.SCHEMA.VIEW`).

Other sign-in options (access token, browser single sign-on, password) are
described in `backend/.env.example`. Restart the backend after changing `.env`.

Windows notes:

- If PowerShell blocks virtual-environment activation, run
  `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` in that terminal.
- On Windows ARM64, create the environment with x64 Python
  (`py -V:3.14-64 -m venv .venv`), because `snowflake-connector-python` has no
  ARM64 build.

### Frontend

```powershell
cd frontend
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
npm install
npm run dev
```

Open `http://localhost:5173`.

## API

- `GET /api/health` - returns `{"status": "ok"}`.
- `GET /api/snowflake/health` - connects to Snowflake and returns the session's
  user, role, warehouse, database and schema.
- `POST /api/chat` - body `{"question": "...", "history": [...]}`. Returns the
  explanation, generated SQL, columns, rows and suggested questions.

Interactive API docs are at `http://localhost:8000/docs`.

## Guardrails

- The service role can only read the semantic view and its tables.
- Cortex Analyst answers only in terms of the semantic view's dimensions and
  metrics.
- The backend runs a generated statement only if it is a `SELECT`.
- Results are capped at 200 rows; questions at 2,000 characters.
- Credentials stay on the backend, and `.env` and key files are excluded from
  source control.

## Limitations

- No user sign-in on the API and no rate limiting.
- No row-level security: every user sees all the data the service role can read.
- Snowflake error text is returned to the browser, which is useful locally but
  should be replaced with generic messages before any deployment.
- No automated tests yet.
