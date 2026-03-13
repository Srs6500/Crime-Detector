# Krogan — Auth & Dependencies

## Auth (no Firebase / no Supabase)

Authentication is handled by the **backend (FastAPI)**. No Firebase or Supabase Auth.

### Sign-in options (first release)

| Option | Use now? | How it works |
|--------|-----------|--------------|
| **Sign in with Apple** | Yes | iOS: `AuthenticationServices` → get identity token. Backend: verify token with Apple's JWKS, extract user id/email, create or link user, issue our JWT. |
| **Phone number** | Yes | User enters phone → backend requests SMS OTP (via Twilio or similar) → user enters code → backend verifies → create or link user, issue our JWT. |
| **Biometric (fingerprint only)** | Later | Deferred. When added: use for app unlock or confirming sensitive actions *after* sign-in, not as primary identity. |

### Backend responsibilities

- Verify Apple identity tokens (Apple’s public keys / JWKS).
- Send and verify phone OTP (Twilio Verify API or equivalent).
- Store users in our Postgres; issue our own JWT (or session) for API/WebSocket auth. JWT is implemented with **PyJWT** (not python-jose; PyJWT is the maintained standard).
- Single account type; guardian linking via invite (no separate guardian login).

### APIs / keys you’ll need

When we implement, you’ll need to provide (I’ll pause and ask):

- **Apple:** Sign in with Apple enabled in App ID; no extra API key for verification (backend uses Apple’s JWKS URL).
- **Phone/SMS:** Twilio (or similar) account — Account SID, Auth Token, and a Verify service (or phone number for SMS). We’re already using Twilio for guardian SMS, so same account can be used for OTP.

### Phone (Twilio) — where we are

- Backend and iOS phone flow are implemented (request OTP, enter code, verify).
- To enable: create a [Twilio](https://www.twilio.com) account, create a **Verify** service in the Twilio console, then add to `apps/backend/.env`: `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SERVICE_SID`. Until those are set, phone sign-in will fail when sending the code.

---

## Dependencies and versions

- **Latest stable only:** Every part of the stack uses the latest stable version at the time we add it — Swift, PostgreSQL, Python, FastAPI, Pinecone, iOS SDK, Swift packages, Python packages, and any other library or service. No pinning to old versions unless there is a documented, unavoidable reason.
- If a specific API key, certificate, or external sign-up is required, implementation will **pause and ask you** to obtain it.
