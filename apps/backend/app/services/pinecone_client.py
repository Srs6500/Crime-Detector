"""
Pinecone vector DB client for RAG in the risk pipeline.
Primary app data stays in Postgres/SQLite; Pinecone is used for embeddings and retrieval.
"""
from __future__ import annotations

from typing import TYPE_CHECKING

from app.core.config import settings

if TYPE_CHECKING:
    from pinecone import Pinecone
    from pinecone.data.index import Index


_pinecone: Pinecone | None = None
_index: Index | None = None


def _get_client() -> Pinecone | None:
    global _pinecone
    if not settings.PINECONE_API_KEY:
        return None
    if _pinecone is None:
        from pinecone import Pinecone

        _pinecone = Pinecone(api_key=settings.PINECONE_API_KEY)
    return _pinecone


def get_pinecone_index() -> Index | None:
    """Return the RAG index if Pinecone is configured; otherwise None.
    Uses PINECONE_INDEX_HOST if set; else looks up host via describe_index (one-time)."""
    global _index
    client = _get_client()
    if client is None:
        return None
    if _index is not None:
        return _index
    host = settings.PINECONE_INDEX_HOST
    if not host:
        desc = client.describe_index(settings.PINECONE_INDEX_NAME)
        host = desc.host
    _index = client.Index(host=host)
    return _index

