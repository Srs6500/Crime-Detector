"""
Saved location endpoints: list, create, delete. All require authentication.
"""
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.guardian import SavedLocation
from app.models.user import User

router = APIRouter()


class LocationCreateBody(BaseModel):
    kind: str  # home, campus, work
    name: str
    latitude: float | None = None
    longitude: float | None = None


@router.get("/locations")
async def list_locations(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    """List current user's saved locations."""
    result = await db.execute(
        select(SavedLocation).where(SavedLocation.user_id == current_user.id).order_by(SavedLocation.kind)
    )
    locations = result.scalars().all()
    return [loc.to_response() for loc in locations]


@router.post("/locations")
async def create_location(
    body: LocationCreateBody,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    """Add a saved location."""
    kind = (body.kind or "home").strip().lower()
    if kind not in ("home", "campus", "work"):
        kind = "home"
    name = (body.name or kind.capitalize()).strip() or kind.capitalize()
    loc = SavedLocation(
        user_id=current_user.id,
        kind=kind,
        name=name,
        latitude=body.latitude,
        longitude=body.longitude,
    )
    db.add(loc)
    await db.flush()
    await db.refresh(loc)
    return loc.to_response()


@router.delete("/locations/{location_id}")
async def delete_location(
    location_id: str,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    """Remove a saved location. Only the owner can delete."""
    result = await db.execute(
        select(SavedLocation).where(
            SavedLocation.id == location_id,
            SavedLocation.user_id == current_user.id,
        )
    )
    loc = result.scalar_one_or_none()
    if not loc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Location not found")
    await db.delete(loc)
    await db.flush()
    return {"ok": True}
