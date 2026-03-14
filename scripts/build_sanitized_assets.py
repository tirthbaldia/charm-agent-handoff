#!/usr/bin/env python3
from __future__ import annotations

import copy
import json
import re
from pathlib import Path

ROOT = Path('/Users/tirthbaldia/charm-agent-handoff')
SRC = Path('/Users/tirthbaldia/Desktop/Capstone/Client_Rebuild_Runbook/exports')

AGENT_SRC = SRC / 'agent' / 'charm.agent.live.json'
LOGGER_SRC = SRC / 'logicapps' / 'la-mck-uc1-logger.live.json'
READER_SRC = SRC / 'logicapps' / 'la-mck-uc1-reader.live.json'
LOGGER_OAS_V6_SRC = SRC / 'tools' / 'log_review_to_sql.spec.v6.source.json'
READER_WRAP_SRC = SRC / 'tools' / 'read_reviews_from_sql.current.wrap.json'
RESOURCE_INVENTORY_SRC = SRC / 'resource_inventory.json'

AGENTS_DIR = ROOT / 'agents' / 'charm'
TOOLS_DIR = AGENTS_DIR / 'tools'
LOGICAPPS_DIR = ROOT / 'logicapps'
DOCS_DIR = ROOT / 'docs'

SUBSCRIPTION_RE = re.compile(r'/subscriptions/[0-9a-fA-F-]+')
UUID_RE = re.compile(r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b')

PLACEHOLDER_MAP = {
    '${AZURE_SUBSCRIPTION_ID}': '${AZURE_SUBSCRIPTION_ID}',
    '${AZURE_TENANT_ID}': '${AZURE_TENANT_ID}',
    '${AZURE_RESOURCE_GROUP}': '${AZURE_RESOURCE_GROUP}',
    '${SQL_SERVER_FQDN}': '${SQL_SERVER_FQDN}',
    '${SQL_DATABASE_NAME}': '${SQL_DATABASE_NAME}',
    'eastus2': '${AZURE_LOCATION}',
    'westus2': '${AZURE_SQL_LOCATION}',
    '${AI_SERVICES_ACCOUNT_NAME}': '${AI_SERVICES_ACCOUNT_NAME}',
    '${FOUNDRY_PROJECT_NAME}': '${FOUNDRY_PROJECT_NAME}',
    'la-mck-uc1-logger': '${LOGICAPP_LOGGER_NAME}',
    'la-mck-uc1-reader': '${LOGICAPP_READER_NAME}',
}


def load_json(path: Path):
    return json.loads(path.read_text(encoding='utf-8'))


def dump_json(path: Path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2, ensure_ascii=True) + '\n', encoding='utf-8')


def sanitize_string(value: str) -> str:
    out = value
    for k, v in PLACEHOLDER_MAP.items():
        out = out.replace(k, v)

    out = SUBSCRIPTION_RE.sub('/subscriptions/${AZURE_SUBSCRIPTION_ID}', out)

    # Logic App callback signatures and callback URLs
    out = re.sub(r'([?&]sig=)[^&\s\"\']+', r'\1${LOGICAPP_CALLBACK_SIG}', out)
    out = out.replace(
        'https://prod-49.${AZURE_LOCATION}.logic.azure.com/workflows/998d427bf7ce4ffab665d4bd7dca5b75/triggers/When_an_HTTP_request_is_received/paths',
        '${LOGICAPP_LOGGER_SERVER_URL}'
    )
    out = out.replace(
        'https://prod-12.${AZURE_LOCATION}.logic.azure.com/workflows/8a424092324348cbbfc43dc7c32a178e/triggers/When_an_HTTP_request_is_received/paths',
        '${LOGICAPP_READER_SERVER_URL}'
    )
    out = out.replace(
        '${LOGICAPP_LOGGER_SERVER_URL}',
        '${LOGICAPP_LOGGER_SERVER_URL}'
    )
    out = out.replace(
        '${LOGICAPP_READER_SERVER_URL}',
        '${LOGICAPP_READER_SERVER_URL}'
    )

    # Access endpoint contains deployment host + workflow id
    out = re.sub(
        r'https://prod-[0-9]+\.[a-z0-9]+\.logic\.azure\.com:443/workflows/[a-z0-9]+',
        '${LOGICAPP_ACCESS_ENDPOINT}',
        out,
    )

    # For highly specific runtime IDs in docs/json snapshots
    out = out.replace('${VECTOR_STORE_ID}', '${VECTOR_STORE_ID}')
    out = out.replace('${MEMORY_STORE_NAME}', '${MEMORY_STORE_NAME}')

    return out


def sanitize_obj(obj):
    if isinstance(obj, dict):
        return {k: sanitize_obj(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [sanitize_obj(v) for v in obj]
    if isinstance(obj, str):
        return sanitize_string(obj)
    return obj


def normalize_tool_spec(spec: dict, is_logger: bool) -> dict:
    spec = sanitize_obj(spec)
    post = spec['paths']['/invoke']['post']

    # Never ship live callback signatures in defaults.
    for param in post.get('parameters', []):
        if param.get('name') == 'sig':
            param.setdefault('schema', {})
            param['schema']['default'] = '${LOGICAPP_CALLBACK_SIG}'

    # Keep explicit operation ids for client tool wiring.
    if is_logger:
        post['operationId'] = 'logReview'
    else:
        post['operationId'] = 'readReviews'

    return spec


def build_agent_assets() -> None:
    raw = load_json(AGENT_SRC)
    latest = raw['versions']['latest']
    definition = copy.deepcopy(latest['definition'])

    # Extract prompt to dedicated file.
    instructions = definition.pop('instructions', '').strip() + '\n'
    (AGENTS_DIR / 'system_prompt.md').write_text(instructions, encoding='utf-8')

    # Sanitize and normalize tool bindings.
    tools = []
    for tool in definition.get('tools', []):
        t = copy.deepcopy(tool)
        if t.get('type') == 'file_search':
            t['vector_store_ids'] = ['${VECTOR_STORE_ID}']
        elif t.get('type') == 'memory_search':
            t['memory_store_name'] = '${MEMORY_STORE_NAME}'
        elif t.get('type') == 'openapi' and 'openapi' in t:
            oas = t['openapi']
            if 'spec' in oas:
                is_logger = oas.get('name') == 'log_review_to_sql'
                oas['spec'] = normalize_tool_spec(oas['spec'], is_logger=is_logger)
            if 'functions' in oas and isinstance(oas['functions'], list):
                for fn in oas['functions']:
                    if 'parameters' in fn and 'properties' in fn['parameters']:
                        if 'sig' in fn['parameters']['properties']:
                            fn['parameters']['properties']['sig']['default'] = '${LOGICAPP_CALLBACK_SIG}'
        tools.append(t)

    definition['model'] = '${FOUNDRY_MODEL_DEPLOYMENT_NAME}'
    definition['tools'] = sanitize_obj(tools)
    definition = sanitize_obj(definition)

    agent_snapshot = {
        'name': '${AGENT_NAME}',
        'source': 'azure-ai-foundry',
        'version': '${AGENT_VERSION}',
        'definition': definition,
    }
    dump_json(AGENTS_DIR / 'agent.definition.json', agent_snapshot)


def build_tool_specs() -> None:
    logger_spec = load_json(LOGGER_OAS_V6_SRC)
    logger_spec = normalize_tool_spec(logger_spec, is_logger=True)
    dump_json(TOOLS_DIR / 'log_review_to_sql.openapi.json', logger_spec)

    reader_wrap = load_json(READER_WRAP_SRC)
    reader_spec = reader_wrap['openapi']['spec']
    reader_spec = normalize_tool_spec(reader_spec, is_logger=False)
    dump_json(TOOLS_DIR / 'read_reviews_from_sql.openapi.json', reader_spec)


def sanitize_logic_app(path: Path, app_type: str) -> dict:
    obj = load_json(path)
    obj = sanitize_obj(obj)

    # Keep only deployment-relevant shape + state metadata.
    sanitized = {
        'name': '${LOGICAPP_LOGGER_NAME}' if app_type == 'logger' else '${LOGICAPP_READER_NAME}',
        'location': '${AZURE_LOCATION}',
        'type': 'Microsoft.Logic/workflows',
        'state': 'Enabled',
        'parameters': obj.get('parameters', {}),
        'definition': obj.get('definition', {}),
    }

    # Stabilize connection refs with placeholders.
    conn = sanitized.get('parameters', {}).get('$connections', {}).get('value', {}).get('sql', {})
    if conn:
        conn['connectionId'] = '/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Web/connections/${SQL_API_CONNECTION_NAME}'
        conn['connectionName'] = '${SQL_API_CONNECTION_NAME}'
        conn['id'] = '/subscriptions/${AZURE_SUBSCRIPTION_ID}/providers/Microsoft.Web/locations/${AZURE_LOCATION}/managedApis/sql'

    # Ensure SQL server/database in API paths are placeholders.
    text = json.dumps(sanitized)
    text = text.replace("'${SQL_SERVER_FQDN}'", "'${SQL_SERVER_FQDN}'")
    text = text.replace("'${SQL_DATABASE_NAME}'", "'${SQL_DATABASE_NAME}'")
    return json.loads(text)


def build_logicapps() -> None:
    logger = sanitize_logic_app(LOGGER_SRC, app_type='logger')
    reader = sanitize_logic_app(READER_SRC, app_type='reader')
    dump_json(LOGICAPPS_DIR / 'la-mck-uc1-logger.workflow.json', logger)
    dump_json(LOGICAPPS_DIR / 'la-mck-uc1-reader.workflow.json', reader)


def build_resource_inventory() -> None:
    inv = sanitize_obj(load_json(RESOURCE_INVENTORY_SRC))
    dump_json(DOCS_DIR / 'resource_inventory.sanitized.json', inv)


def build_manifest() -> None:
    manifest = """agent:
  name: ${AGENT_NAME}
  source: azure-ai-foundry
  runtime_model: foundry-direct-to-teams
  foundry:
    project_endpoint: ${FOUNDRY_PROJECT_ENDPOINT}
    project_name: ${FOUNDRY_PROJECT_NAME}
    model_deployment_name: ${FOUNDRY_MODEL_DEPLOYMENT_NAME}
  prompt:
    file: agents/charm/system_prompt.md
  tools:
    - name: log_review_to_sql
      type: openapi
      spec_file: agents/charm/tools/log_review_to_sql.openapi.json
      server_url_env: LOGICAPP_LOGGER_SERVER_URL
      callback_sig_env: LOGICAPP_LOGGER_SIG
    - name: read_reviews_from_sql
      type: openapi
      spec_file: agents/charm/tools/read_reviews_from_sql.openapi.json
      server_url_env: LOGICAPP_READER_SERVER_URL
      callback_sig_env: LOGICAPP_READER_SIG
    - name: file_search
      vector_store_id_env: VECTOR_STORE_ID
    - name: memory_search
      memory_store_name_env: MEMORY_STORE_NAME

logicapps:
  logger_workflow_file: logicapps/la-mck-uc1-logger.workflow.json
  reader_workflow_file: logicapps/la-mck-uc1-reader.workflow.json

sql:
  server_fqdn_env: SQL_SERVER_FQDN
  database_name_env: SQL_DATABASE_NAME
  schema_path: db/sql
"""
    (AGENTS_DIR / 'manifest.yaml').write_text(manifest, encoding='utf-8')


def main() -> None:
    AGENTS_DIR.mkdir(parents=True, exist_ok=True)
    TOOLS_DIR.mkdir(parents=True, exist_ok=True)
    LOGICAPPS_DIR.mkdir(parents=True, exist_ok=True)
    DOCS_DIR.mkdir(parents=True, exist_ok=True)

    build_agent_assets()
    build_tool_specs()
    build_logicapps()
    build_resource_inventory()
    build_manifest()

    print('Sanitized assets generated under:')
    print(f'- {AGENTS_DIR}')
    print(f'- {LOGICAPPS_DIR}')
    print(f'- {DOCS_DIR / "resource_inventory.sanitized.json"}')


if __name__ == '__main__':
    main()
