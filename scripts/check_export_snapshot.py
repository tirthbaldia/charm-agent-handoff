#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = [
    'agents/charm/system_prompt.md',
    'agents/charm/agent.definition.json',
    'agents/charm/manifest.yaml',
    'agents/charm/tools/log_review_to_sql.openapi.json',
    'agents/charm/tools/read_reviews_from_sql.openapi.json',
    'logicapps/la-mck-uc1-logger.workflow.json',
    'logicapps/la-mck-uc1-reader.workflow.json',
    'db/sql/00_uc1_schema_tables_constraints_indexes.sql',
    'db/sql/10_uc1_procedures.sql',
    'db/sql/20_uc1_views.sql',
    'db/sql/30_uc1_smoke_tests.sql',
]


def main() -> int:
    missing = [p for p in REQUIRED_FILES if not (ROOT / p).exists()]
    if missing:
        print('Missing expected hand-off artifacts:')
        for item in missing:
            print(f'- {item}')
        return 1

    logger = json.loads((ROOT / 'agents/charm/tools/log_review_to_sql.openapi.json').read_text())
    required = logger['paths']['/invoke']['post']['requestBody']['content']['application/json']['schema']['required']
    if 'flags' not in required:
        print('Logger OpenAPI schema is not v6 flags[] compatible.')
        return 1

    print('Export snapshot validation passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
