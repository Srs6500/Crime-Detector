"""
Application configuration via environment variables.
"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    PROJECT_NAME: str = "Krogan API"
    VERSION: str = "0.1.0"
    DEBUG: bool = False

    # API
    API_V1_PREFIX: str = "/api/v1"

    # CORS — adjust for iOS app / web when needed
    CORS_ORIGINS: list[str] = ["*"]

    # Database — default SQLite for local dev (no Postgres needed). For production set to postgresql+asyncpg://...
    DATABASE_URL: str = "sqlite+aiosqlite:///./krogan.db"

    # JWT — set in .env; use long random secrets
    JWT_SECRET_KEY: str = "change-me-in-production"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_EXPIRE_MINUTES: int = 60 * 24  # 24 hours

    # Apple Sign In — backend verifies token with Apple JWKS
    APPLE_TEAM_ID: str = ""
    APPLE_CLIENT_ID: str = ""
    APPLE_KEY_ID: str = ""

    # Twilio — for phone OTP and guardian SMS
    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_VERIFY_SERVICE_SID: str = ""

    # Redis — session state, guardian pub/sub, OTP rate limiting
    REDIS_URL: str = "redis://localhost:6379/0"

    # S3 — audio, photos, evidence (AWS)
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    AWS_REGION: str = "us-east-1"
    S3_BUCKET_MEDIA: str = "krogan-media"

    # APNs — iOS push notifications for guardians
    APNS_KEY_ID: str = ""
    APNS_TEAM_ID: str = ""
    APNS_BUNDLE_ID: str = "com.krogan.app"
    APNS_KEY_PATH: str = ""  # path to .p8 key file

    # Pinecone — vector DB for RAG (embeddings + retrieval in risk pipeline)
    PINECONE_API_KEY: str = ""
    PINECONE_INDEX_NAME: str = "krogan-rag"
    PINECONE_INDEX_HOST: str = ""  # optional; from console or describe_index().host (avoids extra API call)


settings = Settings()
