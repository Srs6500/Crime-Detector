"""
Session endpoints: create session, get active, end session.
All require authentication.
"""
from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.session import Session
from app.models.user import User

router = APIRouter()


class SessionCreateBody(BaseModel):
    mode: str  # rideshare | walking | meetup
    context: str | None = None
    eta_minutes: int | None = None


@router.post("/sessions")
async def create_session(
    body: SessionCreateBody,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    """Start a new session. User can only have one active session at a time."""
    result = await db.execute(
        select(Session).where(
            Session.user_id == current_user.id,
            Session.status == "active",
        )
    )
    existing = result.scalar_one_or_none()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You already have an active session. End it first.",
        )
    mode = (body.mode or "walking").strip().lower()
    if mode not in ("rideshare", "walking", "meetup"):
        mode = "walking"
    session = Session(
        user_id=current_user.id,
        mode=mode,
        context=body.context.strip() or None if body.context else None,
        eta_minutes=body.eta_minutes,
        status="active",
    )
    db.add(session)
    await db.flush()
    await db.refresh(session)
    return session.to_response()


@router.get("/sessions/active")
async def get_active_session(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    """Get current user's active session, if any."""
    result = await db.execute(
        select(Session).where(
            Session.user_id == current_user.id,
            Session.status == "active",
        )
    )
    session = result.scalar_one_or_none()
    if not session:
        return None
    return session.to_response()


@router.patch("/sessions/{session_id}/end")
async def end_session(
    session_id: str,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    """End a session. Only the owner can end it."""
    result = await db.execute(
        select(Session).where(
            Session.id == session_id,
            Session.user_id == current_user.id,
        )
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
    if session.status != "active":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Session already ended")
    session.status = "ended"
    session.ended_at = datetime.now(timezone.utc)
    await db.flush()
    await db.refresh(session)
    return session.to_response()
