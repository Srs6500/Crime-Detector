"""
User endpoints: current user (me).
"""
from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.deps import get_current_user
from app.models.user import User
from app.services.auth_service import user_to_response

router = APIRouter()


@router.get("/me")
async def me(current_user: Annotated[User, Depends(get_current_user)]):
    """Current user. Requires Authorization: Bearer <token>."""
    return user_to_response(current_user)
