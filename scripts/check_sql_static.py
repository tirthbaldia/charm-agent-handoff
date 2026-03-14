#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SQL_DIR = ROOT / 'db' / 'sql'
REQUIRED = [
    '00_uc1_schema_tables_constraints_indexes.sql',
    '10_uc1_procedures.sql',
    '20_uc1_views.sql',
    '30_uc1_smoke_tests.sql',
]


def main() -> int:
    missing = [f for f in REQUIRED if not (SQL_DIR / f).exists()]
    if missing:
        print('Missing SQL files:', ', '.join(missing))
        return 1

    bad = []
    for path in SQL_DIR.glob('*.sql'):
        text = path.read_text(encoding='utf-8')
        if '\t' in text:
            bad.append(f'{path.name}: contains tab characters')
        if 'DROP TABLE' in text and 'IF OBJECT_ID' not in text and path.name.startswith('00_'):
            bad.append(f'{path.name}: unconditional DROP TABLE detected')

    if bad:
        print('SQL static check failed:')
        for issue in bad:
            print('-', issue)
        return 1

    print('SQL static check passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
