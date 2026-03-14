#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

TEXT_EXTS = {
    '.md', '.txt', '.json', '.yaml', '.yml', '.sql', '.py', '.bicep', '.bicepparam', '.env', '.example'
}

# Known values from prototype environment that must not appear in public hand-off.
FORBIDDEN_PATTERNS = [
    r'${AZURE_SUBSCRIPTION_ID}',  # subscription
    r'${AZURE_TENANT_ID}',  # tenant
    r'mck-uc1-server\.database\.windows\.net',
    r'\b${SQL_DATABASE_NAME}\b',
    r'${VECTOR_STORE_ID}',
    r'${MEMORY_STORE_NAME}',
    r'\bsig=[A-Za-z0-9_\-]{20,}',
    r'prod-[0-9]+\.eastus2\.logic\.azure\.com',
]

def is_text_file(path: Path) -> bool:
    if path.suffix in TEXT_EXTS:
        return True
    if path.name in {'.env.example', '.gitignore', 'LICENSE', 'README.md'}:
        return True
    return False


def main() -> int:
    findings: list[tuple[str, str]] = []

    for path in ROOT.rglob('*'):
        if not path.is_file():
            continue
        if '.git' in path.parts:
            continue
        if path.suffix.lower() in {'.pdf', '.png', '.jpg', '.jpeg', '.zip', '.mov', '.pbix'}:
            continue
        if not is_text_file(path):
            continue

        try:
            text = path.read_text(encoding='utf-8')
        except UnicodeDecodeError:
            continue

        for pattern in FORBIDDEN_PATTERNS:
            if re.search(pattern, text):
                findings.append((str(path.relative_to(ROOT)), pattern))

    if findings:
        print('Placeholder/secret validation failed:')
        for rel, pattern in findings:
            print(f'- {rel}: matched `{pattern}`')
        return 1

    print('Placeholder/secret validation passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
