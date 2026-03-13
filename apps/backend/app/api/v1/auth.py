"""
Auth endpoints: Sign in with Apple, phone OTP, token refresh.
Backend verifies Apple token and phone OTP; issues our JWT.
"""
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.core.security import (
    AppleTokenRequest,
    PhoneRequestRequest,
    PhoneVerifyRequest,
    create_access_token,
    get_expires_in_seconds,
)
from app.models.user import User
from app.services.auth_service import (
    get_or_create_user_apple,
    get_or_create_user_phone,
    request_phone_otp,
    user_to_response,
    verify_phone_otp,
)

router = APIRouter()


@router.post("/apple")
async def sign_in_apple(
    body: AppleTokenRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Sign in with Apple: client sends identity_token; backend verifies with Apple JWKS,
    creates or links user, returns our JWT.
    """
    user = await get_or_create_user_apple(db, body.identity_token)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Apple sign-in could not be verified. Try again or use phone number.",
        )
    access_token = create_access_token(subject=str(user.id))
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "expires_in": get_expires_in_seconds(),
        "user": user_to_response(user),
    }


@router.post("/phone/request")
async def phone_otp_request(body: PhoneRequestRequest):
    """Request OTP for phone number. Backend sends SMS via Twilio Verify."""
    phone = body.phone.strip()
    if not phone or not phone.startswith("+"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid phone number; use E.164 format (e.g. +15551234567)",
        )
    ok, msg = await request_phone_otp(phone)
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=msg or "Failed to send OTP",
        )
    return {"message": "OTP sent", "expires_in": 600}


@router.post("/phone/verify")
async def phone_otp_verify(
    body: PhoneVerifyRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Verify OTP code; backend creates or links user, returns our JWT."""
    phone = body.phone.strip()
    code = body.code.strip()
    if not phone or not code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone and code required",
        )
    valid = await verify_phone_otp(phone, code)
    if not valid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired code",
        )
    user = await get_or_create_user_phone(db, phone)
    access_token = create_access_token(subject=str(user.id))
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "expires_in": get_expires_in_seconds(),
        "user": user_to_response(user),
    }


@router.post("/refresh")
async def refresh_token():
    """Refresh JWT using valid refresh token. Not implemented yet."""
    raise HTTPException(501, "Not implemented")
