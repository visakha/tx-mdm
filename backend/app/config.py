"""Settings read from environment variables (or backend/.env). No defaults for secrets."""

from functools import lru_cache

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    idmc_username: str
    idmc_password: SecretStr
    idmc_login_url: str = "https://dm1-us.informaticacloud.com"
    idmc_mdm_url: str = "https://usw1-mdm.dm1-us.informaticacloud.com"
    idmc_platform_url: str = ""
    mdm_resolver_cache_seconds: int = 600
    frontend_origin: str = "http://localhost:5173"
    http_timeout_seconds: float = 30.0


@lru_cache
def get_settings() -> Settings:
    return Settings()  # values come from the environment / .env
