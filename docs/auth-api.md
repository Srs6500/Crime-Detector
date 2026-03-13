# Auth API contract

Single source of truth for auth request/response shapes. Backend and iOS implement this.

**Base URL (dev):** `http://localhost:8000`  
**Prefix:** `/api/v1`

---

## POST /api/v1/auth/apple

Sign in with Apple. Client sends the identity token from `ASAuthorizationAppleIDCredential.identityToken`.

**Request**

```json
{
  "identity_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "authorization_code": "optional_from_ASAuthorizationAppleIDCredential.authorizationCode"
}
```

- `identity_token` (string, required): JWT from Sign in with Apple.
- `authorization_code` (string, optional): Can be sent for future token refresh; not required for first implementation.

**Response 200**

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 1440,
  "user": {
    "id": "uuid",
    "email": "user@privaterelay.appleid.com or null",
    "phone": null
  }
}
```

- `expires_in`: seconds until token expiry (e.g. 86400 = 24 hours).
- `user`: minimal user info; `email` may be null (Apple allows hiding); `phone` null when signed in via Apple.

**Errors**

- 400: Invalid or expired identity_token.
- 401: Apple verification failed.

---

## POST /api/v1/auth/phone/request

Request OTP for a phone number. Backend sends SMS via Twilio Verify.

**Request**

```json
{
  "phone": "+15551234567"
}
```

- `phone` (string, required): E.164 format.

**Response 200**

```json
{
  "message": "OTP sent",
  "expires_in": 600
}
```

- `expires_in`: seconds the code is valid (e.g. 600 = 10 minutes).

**Errors**

- 400: Invalid phone format or rate limited.
- 503: Twilio/send failed.

---

## POST /api/v1/auth/phone/verify

Verify OTP and sign in. Returns same token shape as Apple.

**Request**

```json
{
  "phone": "+15551234567",
  "code": "123456"
}
```

**Response 200**

```json
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "expires_in": 86400,
  "user": {
    "id": "uuid",
    "email": null,
    "phone": "+15551234567"
  }
}
```

**Errors**

- 400: Invalid or expired code.
- 401: Verification failed.

---

## GET /api/v1/me

Current user. Requires `Authorization: Bearer <access_token>`.

**Response 200**

```json
{
  "id": "uuid",
  "email": "user@example.com or null",
  "phone": "+15551234567 or null",
  "created_at": "2025-03-06T12:00:00Z"
}
```

**Errors**

- 401: Missing or invalid token.

---

## Client usage

- After Apple or phone/verify, store `access_token` (e.g. Keychain). Send on every request: `Authorization: Bearer <access_token>`.
- If backend returns 401, clear token and show auth screen again.
