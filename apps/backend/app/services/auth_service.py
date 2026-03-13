"""
Auth business logic: Apple verify, phone OTP, user get-or-create.
"""
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import verify_apple_identity_token
from app.models.user import User


async def get_or_create_user_apple(
    db: AsyncSession,
    identity_token: str,
) -> User | None:
    """
    Verify Apple identity token; get existing user by apple_id or create one.
    Returns User or None if token invalid.
    """
    payload = verify_apple_identity_token(identity_token)
    if not payload:
        return None

    apple_id = payload.get("sub")
    email = payload.get("email")

    if not apple_id:
        return None

    result = await db.execute(select(User).where(User.apple_id == apple_id))
    user = result.scalar_one_or_none()
    if user:
        if email and not user.email:
            user.email = email
            await db.flush()
        return user

    user = User(apple_id=apple_id, email=email)
    db.add(user)
    await db.flush()
    await db.refresh(user)
    return user


async def request_phone_otp(phone: str) -> tuple[bool, str]:
    """
    Send OTP via Twilio Verify. Returns (success, message).
    """
    if not settings.TWILIO_ACCOUNT_SID or not settings.TWILIO_AUTH_TOKEN:
        return False, "Twilio not configured"
    if not settings.TWILIO_VERIFY_SERVICE_SID:
        return False, "Twilio Verify service not configured"

    try:
        from twilio.rest import Client
        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
        verification = client.verify.v2.services(
            settings.TWILIO_VERIFY_SERVICE_SID
        ).verifications.create(to=phone, channel="sms")
        return True, verification.status or "pending"
    except Exception as e:
        return False, str(e)


async def verify_phone_otp(phone: str, code: str) -> bool:
    """Verify OTP with Twilio. Returns True if valid."""
    if not settings.TWILIO_ACCOUNT_SID or not settings.TWILIO_AUTH_TOKEN or not settings.TWILIO_VERIFY_SERVICE_SID:
        return False
    try:
        from twilio.rest import Client
        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
        check = client.verify.v2.services(
            settings.TWILIO_VERIFY_SERVICE_SID
        ).verification_checks.create(to=phone, code=code)
        return check.status == "approved"
    except Exception:
        return False


async def get_or_create_user_phone(db: AsyncSession, phone: str) -> User:
    """Get existing user by phone or create one."""
    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()
    if user:
        return user
    user = User(phone=phone)
    db.add(user)
    await db.flush()
    await db.refresh(user)
    return user


def user_to_response(user: User) -> dict:
    return {
        "id": str(user.id),
        "email": user.email,
        "phone": user.phone,
        "created_at": user.created_at.isoformat() if user.created_at else None,
    }
