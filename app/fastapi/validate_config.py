#!/usr/bin/env python3
from __future__ import annotations

import json
from settings import validate_env


if __name__ == '__main__':
    result = validate_env()
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['ok'] else 1)
