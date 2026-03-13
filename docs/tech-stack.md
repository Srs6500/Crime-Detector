# Krogan — Tech Stack (final)

Single source of truth for the full stack. Follow official docs for each; use latest stable versions.

---

## iOS (apps/ios)

| Component | Choice | Notes |
|-----------|--------|------|
| Language | Swift 6 | [Swift.org](https://swift.org/documentation/) |
| UI | SwiftUI | [Apple Developer](https://developer.apple.com/documentation/swiftui) |
| Min deployment | iOS 18.0 | |
| Auth (client) | Sign in with Apple (`AuthenticationServices`), phone OTP flow | Token/code sent to backend; backend issues JWT. |

---

## Backend (apps/backend)

| Component | Choice | Notes |
|-----------|--------|------|
| Language | Python 3.12+ | |
| Framework | FastAPI | [FastAPI docs](https://fastapi.tiangolo.com/) |
| Server | Uvicorn | ASGI, async |
| Database | PostgreSQL | Async access via SQLAlchemy + asyncpg |
| Cache / pub-sub | Redis (hiredis) | Session state, guardian push, OTP rate limiting, critical-phrase cache |
| Auth (server) | PyJWT | JWT sign/verify; [PyJWT](https://pyjwt.readthedocs.io/). Apple token verification via Apple JWKS. |
| Phone OTP | Twilio Verify | Same Twilio account for guardian SMS. |
| Push (guardians) | aioapns | Async APNs client for iOS push. |
| Object storage | AWS S3 (boto3) | Audio chunks, dashcam photos, evidence. |
| Orchestration | LangGraph | Risk pipeline as stateful graph; fast path for critical phrases. |
| RAG | Graph RAG + Pinecone | Knowledge graph (Title 18 + threat/prosocial). **Pinecone** for vector embeddings and retrieval; hybrid with Graph RAG. |
| Vector DB | **Pinecone** | Vector index for RAG (embeddings + retrieval in risk pipeline). |
| LLM | Groq — Llama 3.1 70B | Structured risk output; 70B for legal/threat reasoning quality. |
| Transcription | AssemblyAI | Streaming STT. |
| Notifications | Twilio (SMS + voice), aioapns (APNs) | Guardian escalation: push → 1 min → SMS → voice. |

---

## Config / env (backend)

See `apps/backend/.env.example`. Key groups:

- **App:** `DEBUG`, `DATABASE_URL`, `JWT_SECRET_KEY`, `CORS_ORIGINS`
- **Apple:** `APPLE_TEAM_ID`, `APPLE_CLIENT_ID`, `APPLE_KEY_ID`
- **Twilio:** `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SERVICE_SID`
- **Redis:** `REDIS_URL`
- **AWS/S3:** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `S3_BUCKET_MEDIA`
- **APNs:** `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID`, `APNS_KEY_PATH`
- **Pinecone:** `PINECONE_API_KEY`, `PINECONE_INDEX_NAME`, `PINECONE_INDEX_HOST` (optional)

---

## Version policy

- Use **latest stable** for every library and service at the time we add or update it.
- Do not pin to old versions unless there is a documented, unavoidable reason.
- When an API key or external sign-up is required, implementation pauses and asks you to obtain it.
