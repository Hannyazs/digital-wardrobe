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

    # Ollama (Gemma 3) — sugestão de metadados da peça (E7.F1.1)
    ollama_url: str = "http://localhost:11434"
    ollama_modelo: str = "gemma3:4b"
    ollama_timeout_s: float = 30.0

    # Storage local (MVP)
    upload_dir: str = "uploads"

    # Sugestões (E5.F1.2): máximo de looks candidatos avaliados por pedido.
    sugestoes_max_candidatos: int = 20000

    # CORS — lista separada por vírgula
    cors_origins: str = "http://localhost:3000"

    @property
    def cors_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
