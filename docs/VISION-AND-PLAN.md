# Krogan — App Vision and Complete Implementation Plan

Single reference for product vision, user flows, backend engine, tech stack, and decisions as described before development started.

---

## 1. Product Vision

**Krogan** is a **mobile safety companion** (not a generic “walk with me” app). It:

- **Listens** (with consent) to real-time voice and text.
- Runs a **tiered risk engine** entirely in the backend.
- Builds **forensic-grade evidence** (audio, telemetry, optional visuals) with verifiable chain-of-custody.
- Activates **tiered guardian / intervention flows** instead of a single SOS button.
- Feeds everything into **descriptive and predictive analytics** so the system gets smarter over time.

**Goal:** Build something better than Citizen — a quiet companion that’s there when it matters, with real intelligence and evidence behind it.

---

## 2. Core User Flows

### A. User side (mobile)

**Onboarding**

- Accept ToS, including consent to audio monitoring and responsibility for local recording laws (one-party vs all-party consent).
- Set up guardians (contacts + priorities).
- Optional “home”, “campus”, “work” locations.
- Register passkey / biometrics (Face ID / fingerprint).

**Start session (“Walk with me”)**

- User chooses: **mode** (rideshare / walking / meetup).
- Optional **context** (e.g. “Uber from X to Y”, “Walking home”, “Meeting someone from Tinder”).
- Optional **ETA** (timer).
- App opens secure WebSocket to backend, starts background audio stream, captures GPS and speed.

**During session**

- User can keep phone idle (pure audio) or use **stealth chat** (dark, feed-style UI) to add text (e.g. “he keeps checking his pockets”).
- At higher stress, tap **Dashcam** to switch from stealth to overt video/burst photos.
- App continuously sends: audio chunks, user text, telemetry (GPS, speed, ETA progress).

**End session**

- User taps “End safely”.
- Backend closes session, finalizes transcription, risk timeline, and evidence package.
- User sees a short **session summary** (no raw score): “Uneventful” / “Mild tension” / “Escalated & handled”.

### B. Guardian side (mobile — same app)

**Setup**

- Accept invite; set relationship (parent, friend, partner) and preferred channels (push, SMS, voice).

**Live monitoring (three states; score stays backend-only)**

- **State 1 — Active (low internal risk):** Optional “Session started” notification. Map, ETA, “Monitoring active.” No transcript/audio.
- **State 2 — Heads Up (medium risk):** Soft “Heads up” push; map + sanitized summaries (e.g. “Short deviation from main road”, “Tone change detected”); “Ping user” (sends neutral “Hey, everything okay?”).
- **State 3 — Overwatch (high risk):** Strong alert (push + SMS; if no response in **1 minute**, then automated voice call). Dashboard: “OVERWATCH ACTIVE”, live transcript, GPS/speed, dashcam feed if enabled. One-tap: “Call user”, “Call emergency near user”, “Mark under control”.

**Escalation**

- Push → if guardian has not opened/acknowledged within **1 minute** → SMS → then (after X more minutes) automated voice call.

---

## 3. Backend Risk and Evidence Engine

### A. Data pipeline per turn

For each new chunk (voice or text):

1. **Transcription:** Audio via WebSocket → AssemblyAI streaming → partial/final transcript.
2. **Context assembly:** Latest text (speech + typed), sliding window of prior transcript, session metadata (mode, ETA, location), user profile.
3. **RAG retrieval:** Embed turn; query **Pinecone** (vector) and **Graph RAG** (Title 18 + threat/prosocial patterns). Attach relevant legal and threat context.
4. **Risk reasoning (Groq / Llama):** Single structured call with turn context + RAG results. Detect coercion, boundary testing, environment. Output: `internal_score` (0–100), tier, labels, narrative summary, evidence tags, legal refs (JSON).
5. **Local rule floor:** Keyword/pattern checks (e.g. “let me out”, “don’t touch me”, “help me”) → auto critical tier; ETA missed / no response → escalate tier.
6. **Persistence:** Logs, risk_analyses, update session/thread; guardian state engine evaluates tier and trend → Active / Heads Up / Overwatch; trigger alerts as needed.

### B. Evidence / forensic layer

- For each audio chunk / image: compute **SHA-256**; store file (e.g. S3) and hash + metadata in DB for chain-of-custody style trail.

### C. Analytics (descriptive + predictive)

- **Descriptive:** Session counts by mode, duration, how often Heads Up/Overwatch; heatmaps; escalation timelines; common triggers.
- **Predictive:** Train on early session telemetry + conversation features + environment to estimate probability of escalation and time-to-escalation; use to pre-emptively move Active → Heads Up and prioritize evidence capture.

---

## 4. Tech Stack

### iOS (apps/ios)

| Component        | Choice                                      |
|-----------------|---------------------------------------------|
| Language        | Swift 6                                     |
| UI              | SwiftUI                                     |
| Platform        | iOS only (USA focus)                        |
| Min deployment  | iOS 18.0                                    |
| Auth (client)   | Sign in with Apple, phone OTP (backend JWT) |

### Backend (apps/backend)

| Component     | Choice                    |
|--------------|---------------------------|
| Language     | Python 3.12+              |
| Framework    | FastAPI                   |
| Server       | Uvicorn (ASGI, async)     |
| Primary DB   | PostgreSQL (SQLite for local dev) |
| **Vector DB**| **Pinecone** (RAG; embeddings + retrieval) |
| Graph RAG    | Knowledge graph (Title 18 + threat patterns); graph DB TBD (Neo4j / FalkorDB / Postgres) |
| Cache/pub-sub| Redis (session state, guardian push, OTP rate limiting) |
| Auth (server)| PyJWT; Apple JWKS; Twilio Verify for phone |
| Push         | aioapns (APNs) for guardians |
| Object storage | AWS S3 (boto3) for audio, photos, evidence |
| Orchestration| LangGraph (risk pipeline; fast path for critical phrases) |
| LLM          | Groq — Llama 3.1 70B (structured risk output) |
| Transcription| AssemblyAI (streaming STT) |
| Notifications| Twilio (SMS + voice), APNs |

### Version policy

- **Latest stable** for all libraries and services; no pinning to old versions unless documented.

---

## 5. Security and Privacy

- **Scores and raw risk data:** Backend-only; frontend and guardians see only states (Active / Heads Up / Overwatch) and human-readable summaries.
- **Consent and transparency:** Clear onboarding about recording and data use; user responsible for one-party vs all-party consent.
- **Retention and deletion:** Fixed retention window so data and caches don’t grow unbounded or become corrupted; alignment with chain-of-custody and TTL where needed.
- **Zero-trust, JWT on every request;** OWASP mobile + API practices.

---

## 6. Key Decisions Made

- **One account type:** No separate “guardian login”; everyone signs up the same way; guardian linking via **invite** (accept in same app → Guardian section appears).
- **First escalation window:** **1 minute** (push unread → SMS) so backend and RAG have time without delaying emergency response.
- **Legal refs:** From **Title 18** (federal crime law) dataset for RAG and risk labels.
- **Stealth UI:** Feed-style (generic social feed), not weather or other themes.
- **Guardian onboarding:** Short and to-the-point.
- **No Firebase/Supabase:** Auth and data on our backend (FastAPI + Postgres/SQLite + Pinecone, etc.).
- **Monorepo (for GitHub):** One repo (iOS app, backend, docs); imports at top of file; meaningful concurrency; logical, clean code.

---

## 7. UI/UX Direction

- **Tone:** Calm until it can’t be; minimal and premium (dark mode default).
- **Primary CTA:** “Walk with me” on Home; session setup (mode, context, ETA) in bottom sheet.
- **In-session:** Minimal default view; stealth = generic feed with hidden note input; Dashcam = overt camera + burst photos.
- **Session summary:** Outcome tag only (Uneventful / Mild tension / Escalated & handled).
- **Guardian:** One view that changes by state (map + status + actions); escalation via push → SMS → voice.

---

## 8. Implementation Order (as planned)

1. Auth (Sign in with Apple + phone OTP) — **done**
2. Onboarding (Welcome, Consent, Biometrics placeholder, Guardians, Optional locations, Ready)
3. Home + “Walk with me” + session setup
4. Active session, stealth feed, dashcam, end session + summary
5. Backend: Pinecone + Graph RAG, LangGraph risk pipeline, AssemblyAI, Groq
6. Guardian flows (invite, states, notifications, escalation)
7. Evidence (hashing, S3), analytics (descriptive then predictive)

---

This document is the **verbatim** vision and complete implementation plan plus tech stack (including **Pinecone** as the vector DB for RAG). We build with Pinecone for the RAG/risk layer; primary app data stays in Postgres (or SQLite for local dev).
