"""
Guardian and SavedLocation models: user's emergency contacts and optional places.
"""
import uuid
from typing import Optional

from sqlalchemy import Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.user import Base


def _uuid_default() -> str:
    return str(uuid.uuid4())


class Guardian(Base):
    __tablename__ = "guardians"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=_uuid_default
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    phone: Mapped[str] = mapped_column(String(20), nullable=False)
    priority: Mapped[int] = mapped_column(Integer, nullable=False, default=1)  # 1 primary, 2 secondary, 3 backup

    def to_response(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "phone": self.phone,
            "priority": self.priority,
        }


class SavedLocation(Base):
    __tablename__ = "saved_locations"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=_uuid_default
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    kind: Mapped[str] = mapped_column(String(32), nullable=False)  # home, campus, work
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    latitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    longitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    def to_response(self) -> dict:
        return {
            "id": self.id,
            "kind": self.kind,
            "name": self.name,
            "latitude": self.latitude,
            "longitude": self.longitude,
        }
