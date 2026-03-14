#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

LINK_RE = re.compile(r'\[[^\]]+\]\(([^)]+)\)')


def is_external(target: str) -> bool:
    return target.startswith('http://') or target.startswith('https://') or target.startswith('mailto:')


def main() -> int:
    errors: list[str] = []
    for md in ROOT.rglob('*.md'):
        text = md.read_text(encoding='utf-8')
        for match in LINK_RE.findall(text):
            target = match.split('#', 1)[0].strip()
            if not target or is_external(target):
                continue
            resolved = (md.parent / target).resolve()
            if not resolved.exists():
                errors.append(f'{md.relative_to(ROOT)} -> {target}')

    if errors:
        print('Broken markdown links:')
        for err in errors:
            print('-', err)
        return 1

    print('Docs link check passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
