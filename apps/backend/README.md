# Krogan Backend

Python + FastAPI API for Krogan. Handles auth (Apple + phone OTP), sessions, guardians, risk engine integration, and notifications.

## Setup

- Python 3.12+
- Create a virtualenv and install:

```bash
cd apps/backend
python -m venv .venv
source .venv/bin/activate   # or .venv\Scripts\activate on Windows
pip install -e ".[dev]"
```

- Copy `.env.example` to `.env` and set `DATABASE_URL`, `JWT_SECRET_KEY`. Add Apple/Twilio keys when implementing auth.

## Run

```bash
uvicorn app.main:app --reload
```

- API: http://localhost:8000
- Docs: http://localhost:8000/docs (when DEBUG or docs_url enabled)

## Structure

- `app/main.py` — FastAPI app
- `app/core/` — config (includes Redis, S3, APNs placeholders), security
- `app/api/v1/` — API routers (auth, users, sessions, guardians, etc.)
- `app/models/` — SQLAlchemy models (to add)
- `app/services/` — business logic (to add)

## Stack (see repo docs/tech-stack.md)

Postgres, Redis, PyJWT, LangGraph, Graph RAG, Groq (Llama 3.1 70B), AssemblyAI, Twilio, aioapns, boto3. All latest stable.
