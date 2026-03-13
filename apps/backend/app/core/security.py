"""
JWT creation/verification and Apple identity token verification.
"""
import logging
from datetime import datetime, timezone, timedelta
from typing import Any

import jwt
from jwt import PyJWKClient
from pydantic import BaseModel

from app.core.config import settings


# --- JWT ---

def create_access_token(subject: str, expires_delta: timedelta | None = None) -> str:
    if expires_delta is None:
        expires_delta = timedelta(minutes=settings.JWT_ACCESS_EXPIRE_MINUTES)
    expire = datetime.now(timezone.utc) + expires_delta
    payload = {"sub": subject, "exp": expire, "iat": datetime.now(timezone.utc)}
    return jwt.encode(
        payload,
        settings.JWT_SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM,
    )


def decode_access_token(token: str) -> dict[str, Any] | None:
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        return payload
    except jwt.PyJWTError:
        return None


def get_expires_in_seconds() -> int:
    return settings.JWT_ACCESS_EXPIRE_MINUTES * 60


# --- Apple Sign In ---

APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"


def verify_apple_identity_token(identity_token: str) -> dict[str, Any] | None:
    """
    Verify Sign in with Apple identity token using Apple's JWKS.
    Returns decoded payload (sub, email, etc.) or None if invalid.
    """
    try:
        jwks_client = PyJWKClient(APPLE_JWKS_URL)
        signing_key = jwks_client.get_signing_key_from_jwt(identity_token)
        decode_kw: dict = {
            "algorithms": ["RS256"],
            "issuer": "https://appleid.apple.com",
        }
        if settings.APPLE_CLIENT_ID:
            decode_kw["audience"] = settings.APPLE_CLIENT_ID
        else:
            decode_kw["options"] = {"verify_aud": False}
        payload = jwt.decode(
            identity_token,
            signing_key.key,
            **decode_kw,
        )
        return payload
    except Exception as e:
        logging.warning(
            "Apple identity token verification failed: %s (set APPLE_CLIENT_ID=com.krogan.app in .env)",
            e,
            exc_info=settings.DEBUG,
        )
        return None


# --- Request/response schemas used by auth routes ---

class AppleTokenRequest(BaseModel):
    identity_token: str
    authorization_code: str | None = None


class PhoneRequestRequest(BaseModel):
    phone: str


class PhoneVerifyRequest(BaseModel):
    phone: str
    code: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: dict
