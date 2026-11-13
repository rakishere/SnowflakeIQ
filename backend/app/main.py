import os
from typing import Any, Literal

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.encoders import jsonable_encoder
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from app.cortex_analyst import AnalystError, ask
from app.snowflake_client import SnowflakeConfigError, fetch_session_info

load_dotenv()

origins = [
    origin.strip()
    for origin in os.getenv(
        "FRONTEND_ORIGINS",
        "http://localhost:5173,http://127.0.0.1:5173",
    ).split(",")
    if origin.strip()
]

app = FastAPI(title="SnowflakeIQ API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ChatMessage(BaseModel):
    role: Literal["user", "analyst"]
    content: list[dict[str, Any]]


class ChatRequest(BaseModel):
    question: str = Field(min_length=1, max_length=2000)
    history: list[ChatMessage] = Field(default_factory=list, max_length=40)


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/snowflake/health")
def snowflake_health() -> dict[str, str | None]:
    """Connect to Snowflake and report the session context."""
    try:
        info = fetch_session_info()
    except SnowflakeConfigError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error
    except ModuleNotFoundError as error:
        raise HTTPException(
            status_code=503,
            detail="snowflake-connector-python is not installed in the backend venv",
        ) from error
    except Exception as error:
        raise HTTPException(
            status_code=502, detail=f"Snowflake connection failed: {error}"
        ) from error
    return {"status": "ok", **info}


@app.post("/api/chat")
def chat(request: ChatRequest) -> Any:
    """Answer a natural-language question through Cortex Analyst."""
    question = request.question.strip()
    if not question:
        raise HTTPException(status_code=422, detail="Question is empty")

    history = [message.model_dump() for message in request.history]
    try:
        answer = ask(question, history)
    except SnowflakeConfigError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error
    except AnalystError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    except Exception as error:
        raise HTTPException(
            status_code=502, detail=f"Snowflake request failed: {error}"
        ) from error
    # Rows can hold Decimal and date values, which need JSON-safe encoding.
    return jsonable_encoder(answer)
