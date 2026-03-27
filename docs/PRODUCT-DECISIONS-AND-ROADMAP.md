# Krogan — Product Decisions & Implementation Roadmap

Single reference for product rules (guardians, dashcam, escalation), safety tiers, and what to build next. Complements `VISION-AND-PLAN.md` for high-level vision and tech stack.

---

## 1. Product decisions (locked in)

### 1.1 No-guardian path

- **We respect users who don’t want guardians** (e.g. feeling depressed, or prefer no contacts).
- **Onboarding:** Users may **skip** adding guardians and still complete onboarding and use “Walk with me.”
- **Later:** They can add guardians anytime via **Settings → Manage guardians** (or equivalent). No need to add them during onboarding.

### 1.2 Dashcam rules

| User type | Dashcam during session |
|-----------|------------------------|
| **No guardians** | **Always on.** Ensures a recording exists even when no one is actively monitoring. |
| **Has guardians** | **Voluntary.** User can turn the camera on whenever they want (e.g. before a perceived threat). Not gated by risk tier. |

### 1.3 User-triggered escalation: discreet manual override

- **Primary safety signal:** AI/risk engine remains the main driver for escalation decisions in the backend.
- **Manual override required:** Keep explicit user-triggered escalation, but avoid loud/obvious UI in hostile scenarios.
- **No voice trigger:** We do **not** use a separate “shout help” voice trigger. The risk engine already uses voice/context for tier detection; adding a “help” keyword would introduce another source of false positives (conversation, TV, unclear speech).
- **Direction:** Prefer discreet triggers (e.g. hardware-button gesture) over a visually loud emergency control on the main session screen.

### 1.4 Safety tiers (for users and guardians)

- **Active (low):** Optional “Session started” notification. Map, ETA. No transcript/audio to guardians.
- **Heads Up (medium):** Soft “Heads up” push; map + sanitized summaries; “Ping user.”
- **Overwatch (high):** Strong alert (push → SMS if no ack in 1 min → voice). Live view: transcript, GPS, dashcam if on. One-tap: “Call user”, “Call emergency”, “Mark under control.”

**Guardian priority (Primary / Secondary / Backup):** Defines **who we contact first** when we notify; escalation can go to the next if needed. Users can learn this via a short “How alerts work” / “Safety levels” explainer in the app (e.g. from Guardians or Settings).

### 1.5 Guardian add/remove behavior

- **Remove guardians:** Users can remove guardians from **Manage Guardians** (iOS supports delete via swipe/context menu; backend has `DELETE /api/v1/guardians/{guardian_id}`).
- **When adding a guardian now:** Adding a guardian currently saves contact + priority to the user account. It does **not** send an invite SMS/push to that person yet.
- **Planned:** Add explicit guardian invite/consent notification flow (SMS first; in-app invite acceptance when guardian has Krogan installed).

### 1.6 Live-session stealth requirement

- **Current issue:** The live-session screen must not look like an obvious safety app in high-risk situations (e.g. rideshare attacker glance).
- **Requirement:** Add **Stealth / Decoy Mode** entry from active session.
- **Stealth behavior:** Either full black screen (phone appears inactive/locked) or decoy surface (e.g. neutral fake screen). Background monitoring/streaming continues.
- **Controlled high-risk mode:** Stealth/decoy behavior is not default; it is an explicit, user-chosen high-risk mode with clear warning copy.
- **Risk note:** If decoy behavior is discovered, danger may escalate. Keep quick exit/off controls and safe fallback behavior.

### 1.7 Dashcam UX requirement (overt deterrent mode)

- Dashcam must be an intentional, high-confidence action (not a tiny control near text input).
- When activated, UI should switch clearly into overt recording/broadcast mode (camera viewfinder + red recording treatment).
- This mode is intentionally visible and deterrent; stealth mode is the opposite path.

### 1.8 Rogue guardian counter-intelligence mode (controlled high-risk)

- **Use case:** For coercive control / suspected abusive guardian scenarios.
- **Design:** Maintain two parallel tracks:
  - **Evidence track (immutable):** raw recordings + metadata + hashes, untouched by AI.
  - **Analysis track (AI):** transcript/summaries/risk labels as separate derived artifacts.
- **Guardian Suspicion Mode:** treat this as a controlled high-risk mode, not default guardian behavior.
- **Behavior in this mode:** decoy/bluff guardian-facing stream may be used; user receives concise live risk commentary/flagged quotes (not giant transcript walls).
- **Legal/forensic note:** AI output is assistive intelligence, not primary evidentiary source; preserve chain-of-custody for raw data.
- **Safety note:** provide explicit warnings, auditability, and safe rollback to standard guardian mode.

---

## 2. Implementation roadmap

### 2.1 Done

- Auth (Sign in with Apple + phone OTP, JWT).
- Onboarding: Welcome, Consent, Biometrics placeholder, Guardians, Optional locations, Ready.
- Home + “Walk with me” + session setup (mode, context, ETA).
- Active session: stealth-style UI, notes, End safely, session summary.
- Backend: sessions, guardians, saved locations (APIs + DB); Pinecone for RAG (configured).
- iOS: Manage Guardians (list, add, delete); onboarding syncs guardians/locations to backend.
- Guardian add currently stores contact + priority only (no outbound invite notification yet).
- Decisions: tap-only escalation, dashcam rules, no-guardian path, single explainer for tiers/guardian priority.

### 2.2 Next: app (product completeness)

1. **No-guardian onboarding**
   - Allow “Skip” or “I’ll add guardians later” on the Guardians step so users can finish without adding anyone.
   - Session can start with zero guardians; backend supports it.

2. **Stealth / Decoy Mode (active session)**
   - Add explicit “Enter Stealth Mode” action.
   - Show black/decoy screen while session monitoring continues in background.
   - Ensure returning to normal session UI is quick and safe.

3. **Discreet manual escalation trigger**
   - Replace/de-emphasize loud on-screen emergency affordance in normal session UI.
   - Add hardware-button gesture trigger path for immediate Overwatch request.
   - Keep backend endpoint handling explicit escalation requests.

4. **Dashcam behavior and overt UI**
   - **No guardians:** Dashcam always on for the duration of session (policy remains).
   - **Has guardians:** Dashcam remains voluntary.
   - Upgrade control to a clear intentional action (button/slider) and transition into overt camera recording UI.

5. **Settings**
   - Lightweight screen (e.g. from Home): Manage guardians (link to existing), Manage locations (if implemented), account/notifications.
   - Ensures “add guardians later” has a clear place.

6. **Optional: “How alerts work”**
   - Small entry point (e.g. on Guardians screen or in Settings) that opens a short explainer: three safety states (Active / Heads Up / Overwatch) and “We contact your Primary guardian first; we may escalate to others if needed.”
   - Include controlled high-risk mode caveats (when to use, risks, and rollback).

### 2.3 Then: backend (live session + risk + notifications)

6. **WebSocket / streaming for session**
   - App streams audio chunks (and optionally GPS/telemetry) during “Walk with me.” Backend receives and feeds the risk pipeline.

7. **Minimal risk pipeline**
   - Ingest audio → transcribe (e.g. AssemblyAI) → optional RAG (Pinecone) → rule floor (e.g. “let me out”, “help me”) → output tier (Active / Heads Up / Overwatch) and persist. Add LLM (e.g. Groq) when ready.

8. **Session state in DB**
   - Store current tier per session so guardian logic and app can react.

9. **Guardian notifications**
   - On tier change (or on tap-to-escalate): notify guardians per priority; push (APNs) → SMS (Twilio) if no ack in 1 min → voice as needed. Tap-to-escalate sets session to Overwatch and runs the same flow.

10. **Evidence**
    - Audio/video chunks to S3, SHA-256, log in DB (chain-of-custody).

11. **Guardian add invite/consent notifications**
    - On `POST /guardians`, trigger invite notification to the added contact (Twilio SMS deep link; optional APNs if existing user).
    - Support accept/decline and consent tracking; only accepted guardians are used for escalation notifications.
    - Add retry/idempotency and clear delivery status so users can re-send invites safely.

### 2.4 Later

- Guardian invite flow (invite, accept in app, guardian-specific view).
- Graph RAG, predictive analytics.
- Full LangGraph pipeline, AssemblyAI streaming, Groq structured output.

---

## 3. Summary table

| Topic | Decision |
|-------|----------|
| Guardians in onboarding | Optional; can skip and add later in Settings. |
| No-guardian users | Allowed; dashcam always on during session. |
| Users with guardians | Dashcam voluntary (tap to turn on when they want). |
| Live session stealth | Required; add stealth/decoy mode so UI does not expose safety intent. |
| “I need help” / escalate | Discreet manual override (prefer hardware gesture); no voice “help” trigger. |
| Controlled high-risk mode | Required for stealth/rogue-guardian features; explicit user opt-in, warnings, and safe rollback. |
| Safety tiers | Active → Heads Up → Overwatch; backend-only score; user/guardian see states and summaries. |
| Guardian priority | Primary first; escalate to Secondary/Backup as needed. |
| Where to add guardians later | Settings (e.g. “Manage guardians” → existing Manage Guardians screen). |
| Add guardian notification | **Not yet live**; planned as invite/consent flow before full guardian escalation rollout. |

---

*This document reflects product decisions and the implementation order as of the last update. For vision, tech stack, and risk-engine detail, see `VISION-AND-PLAN.md` and `risk-engine-and-rag.md`.*
