from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Base de datos
    database_url: str = "postgresql://heatmapper_user:password@db:5432/heatmapper"

    # Seguridad JWT
    secret_key: str = "cambia_esto_por_un_secreto_seguro"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 7

    # Servidor
    debug: bool = False
    cors_origins: list[str] = ["http://localhost", "http://localhost:5173"]

    # Storage local de planos
    plano_storage_dir: str = "storage/planos"
    plano_max_size_bytes: int = 10 * 1024 * 1024


settings = Settings()
