from __future__ import annotations

import os
from dataclasses import dataclass

try:
    from dotenv import load_dotenv
except ModuleNotFoundError:  # Optional for local validation before deps install
    def load_dotenv(*_args, **_kwargs):
        return False


load_dotenv()


@dataclass
class Settings:
    app_host: str = os.getenv('APP_HOST', '0.0.0.0')
    app_port: int = int(os.getenv('APP_PORT', '8080'))

    logicapp_logger_server_url: str = os.getenv('LOGICAPP_LOGGER_SERVER_URL', '')
    logicapp_reader_server_url: str = os.getenv('LOGICAPP_READER_SERVER_URL', '')
    logicapp_logger_sig: str = os.getenv('LOGICAPP_LOGGER_SIG', '')
    logicapp_reader_sig: str = os.getenv('LOGICAPP_READER_SIG', '')

    sql_server_fqdn: str = os.getenv('SQL_SERVER_FQDN', '')
    sql_database_name: str = os.getenv('SQL_DATABASE_NAME', '')

    foundry_project_endpoint: str = os.getenv('FOUNDRY_PROJECT_ENDPOINT', '')
    foundry_model_deployment_name: str = os.getenv('FOUNDRY_MODEL_DEPLOYMENT_NAME', '')


REQUIRED_KEYS = [
    'LOGICAPP_LOGGER_SERVER_URL',
    'LOGICAPP_READER_SERVER_URL',
    'LOGICAPP_LOGGER_SIG',
    'LOGICAPP_READER_SIG',
    'SQL_SERVER_FQDN',
    'SQL_DATABASE_NAME',
    'FOUNDRY_PROJECT_ENDPOINT',
    'FOUNDRY_MODEL_DEPLOYMENT_NAME',
]


def validate_env() -> dict:
    missing = [k for k in REQUIRED_KEYS if not os.getenv(k)]
    return {
        'ok': not missing,
        'missing': missing,
    }
