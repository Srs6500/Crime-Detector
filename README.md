# Krogan

Mobile safety companion: real-time voice + text monitoring, tiered risk engine, guardian flows, and forensic evidence. iOS (Swift) + Python/FastAPI backend.

## Repo structure (monorepo)

```
Krogan/
├── apps/
│   ├── ios/          # Native Swift/SwiftUI app (iOS 18+)
│   └── backend/      # FastAPI API (auth, sessions, guardians, risk engine)
├── docs/             # Specs, auth, dependencies
├── .cursor/rules/    # Project and iOS coding rules
└── README.md
```

## Quick start

**Backend**

```bash
cd apps/backend
python -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env   # set DATABASE_URL, JWT_SECRET_KEY
uvicorn app.main:app --reload
```

**iOS**

```bash
cd apps/ios
xcodegen generate     # requires: brew install xcodegen
open Krogan.xcodeproj
```

See `apps/backend/README.md` and `apps/ios/README.md` for details.

## Auth

- Sign in with Apple + phone number (OTP). No Firebase/Supabase. Backend issues JWT. See [docs/auth-and-deps.md](docs/auth-and-deps.md).

## Tech stack

- **iOS:** Swift 6, SwiftUI, iOS 18. Latest stable.
- **Backend:** Python 3.12+, FastAPI, Postgres (async), **Redis** (session state, guardian push, rate limiting), **PyJWT** (auth), **LangGraph** (risk pipeline), **Pinecone** (vector RAG), **Graph RAG** (knowledge layer), **Groq Llama 3.1 70B**, AssemblyAI, Twilio, **aioapns** (APNs), **boto3** (S3). Latest stable.
- Full list: [docs/tech-stack.md](docs/tech-stack.md). Risk engine & RAG: [docs/risk-engine-and-rag.md](docs/risk-engine-and-rag.md).
