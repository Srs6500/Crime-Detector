"""
Guardian endpoints: list, create, delete. All require authentication.
"""
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.guardian import Guardian
from app.models.user import User

router = APIRouter()


class GuardianCreateBody(BaseModel):
    name: str
    phone: str
    priority: int = 1  # 1 primary, 2 secondary, 3 backup


@router.get("/guardians")
async def list_guardians(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    """List current user's guardians."""
    result = await db.execute(
        select(Guardian).where(Guardian.user_id == current_user.id).order_by(Guardian.priority, Guardian.name)
    )
    guardians = result.scalars().all()
    return [g.to_response() for g in guardians]


@router.post("/guardians")
async def create_guardian(
    body: GuardianCreateBody,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    """Add a guardian."""
    name = (body.name or "").strip()
    phone = (body.phone or "").strip()
    if not name or not phone:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Name and phone required")
    if not phone.startswith("+"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Phone must be E.164 (e.g. +15551234567)")
    priority = body.priority if body.priority in (1, 2, 3) else 1
    guardian = Guardian(
        user_id=current_user.id,
        name=name,
        phone=phone,
        priority=priority,
    )
    db.add(guardian)
    await db.flush()
    await db.refresh(guardian)
    return guardian.to_response()


@router.delete("/guardians/{guardian_id}")
async def delete_guardian(
    guardian_id: str,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    """Remove a guardian. Only the owner can delete."""
    result = await db.execute(
        select(Guardian).where(
            Guardian.id == guardian_id,
            Guardian.user_id == current_user.id,
        )
    )
    guardian = result.scalar_one_or_none()
    if not guardian:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Guardian not found")
    await db.delete(guardian)
    await db.flush()
    return {"ok": True}
