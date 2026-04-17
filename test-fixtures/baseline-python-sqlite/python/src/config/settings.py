"""Settings — loaded from environment. Fail loudly on missing required vars."""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    env: str = "development"
    PORT: int = 8080
    LOG_LEVEL: str = "info"
    DEV_MODE: bool = True

    ALLOWED_HOSTS: list[str] = ["localhost", "127.0.0.1"]
    CORS_ORIGINS: list[str] = ["http://localhost:3000"]
    RATE_LIMIT: int = 100
    MAX_REQUEST_BODY_BYTES: int = 1_048_576

    OKTA_ISSUER: str = ""
    OKTA_CLIENT_ID: str = ""
    OKTA_REQUIRED_GROUPS: list[str] = []

    DATABASE_URL: str = ""

    def require_production_secrets(self) -> None:
        """Fail fast if production is missing required env vars."""
        if self.DEV_MODE:
            return
        if not self.OKTA_ISSUER or not self.OKTA_CLIENT_ID:
            raise RuntimeError("OKTA_ISSUER and OKTA_CLIENT_ID required in production")
        if not self.DATABASE_URL:
            raise RuntimeError("DATABASE_URL required in production")


settings = Settings()
