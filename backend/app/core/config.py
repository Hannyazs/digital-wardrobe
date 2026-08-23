from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configurações da aplicação, lidas de variáveis de ambiente / .env."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Banco de dados
    database_url: str
    alembic_database_url: str

    # Supabase Auth
    supabase_jwt_secret: str
    supabase_url: str = ""
    supabase_service_key: str = ""

    # Gemini Vision
    gemini_api_key: str = ""

    # Storage local (MVP)
    upload_dir: str = "uploads"

    # CORS — lista separada por vírgula
    cors_origins: str = "http://localhost:3000"

    @property
    def cors_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
