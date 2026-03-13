from fastapi import APIRouter

from app.api.v1 import auth, users, sessions

router = APIRouter()
router.include_router(auth.router, prefix="/auth", tags=["auth"])
router.include_router(users.router, tags=["users"])
router.include_router(sessions.router, tags=["sessions"])
