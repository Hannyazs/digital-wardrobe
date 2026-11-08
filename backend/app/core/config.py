from functools import lru_cache
from typing import Literal

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configurações da aplicação, lidas de variáveis de ambiente / .env."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # "desenvolvimento" (padrão) ou "producao" (E9.F3.2). Em produção a API
    # recusa subir com configuração de desenvolvimento perigosa (ver
    # `_conferir_producao`).
    ambiente: Literal["desenvolvimento", "producao"] = "desenvolvimento"

    # Banco de dados
    database_url: str
    alembic_database_url: str

    # Supabase Auth (E9.F1.1). `supabase_url` é a URL da API do projeto
    # (https://<ref>.supabase.co); as chaves públicas vêm de <url>/auth/v1/.well-known/jwks.json.
    supabase_url: str = ""
    # Só para tokens de desenvolvimento (HS256, scripts/gerar_token_teste.py).
    # Vazio desliga esse tipo de token — é o valor de produção.
    supabase_jwt_secret: str = ""
    # Chave secreta do Supabase (Storage, Épico 10). Só no backend, nunca no app.
    supabase_service_key: str = ""

    # Ollama (Gemma 3) — sugestão de metadados da peça (E7.F1.1)
    ollama_url: str = "http://localhost:11434"
    ollama_modelo: str = "gemma3:4b"
    ollama_timeout_s: float = 30.0
    # Tempo total da sugestão de look a partir de uma referência (E8.F5.2): esgotado,
    # as etiquetas que faltam ficam "não analisadas" e o resultado sai com o que deu.
    sugestao_tempo_max_s: float = 120.0

    # Storage local (MVP)
    upload_dir: str = "uploads"

    # Sugestões (E5.F1.2): máximo de looks candidatos avaliados por pedido.
    sugestoes_max_candidatos: int = 20000

    # CORS — origens do app que podem chamar a API, separadas por vírgula.
    cors_origins: str = "http://localhost:3000"

    @property
    def cors_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def em_producao(self) -> bool:
        return self.ambiente == "producao"

    @model_validator(mode="after")
    def _conferir_producao(self) -> "Settings":
        """Em produção, falha logo ao subir em vez de rodar com padrões de
        desenvolvimento (E9.F3.2). Em desenvolvimento, nada muda."""
        if not self.em_producao:
            return self
        problemas = []
        if not self.supabase_url.startswith("https://"):
            problemas.append("SUPABASE_URL precisa ser a URL https do projeto Supabase")
        if self.supabase_jwt_secret:
            problemas.append("SUPABASE_JWT_SECRET precisa ficar vazio (desliga os tokens de teste)")
        origens = self.cors_origins_list
        if not origens:
            problemas.append("CORS_ORIGINS precisa listar as origens do app")
        for origem in origens:
            if origem == "*":
                problemas.append("CORS_ORIGINS não pode ser '*'")
            elif not origem.startswith("https://"):
                problemas.append(f"CORS_ORIGINS só aceita origens https em produção (recebido: {origem})")
            elif "localhost" in origem or "127.0.0.1" in origem:
                problemas.append(f"CORS_ORIGINS não pode ter origem local em produção (recebido: {origem})")
        if problemas:
            raise ValueError("Configuração inválida para produção: " + "; ".join(problemas))
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
