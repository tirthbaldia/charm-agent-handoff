#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
import requests
from dotenv import load_dotenv

load_dotenv()


def invoke(base_url: str, sig: str, payload: dict) -> requests.Response:
    url = (
        f"{base_url}/invoke"
        f"?api-version=2019-05-01"
        f"&sp=/triggers/When_an_HTTP_request_is_received/run"
        f"&sv=1.0"
        f"&sig={sig}"
    )
    return requests.post(url, json=payload, timeout=30)


def main() -> int:
    if len(sys.argv) < 2 or sys.argv[1] not in {'logger', 'reader'}:
        print('Usage: smoke_logicapps.py [logger|reader]')
        return 2

    mode = sys.argv[1]
    if mode == 'logger':
        base = os.getenv('LOGICAPP_LOGGER_SERVER_URL', '')
        sig = os.getenv('LOGICAPP_LOGGER_SIG', '')
        payload = {
            'project_number': 'SMOKE-001',
            'title': 'Smoke Test Proposal',
            'business_unit': 'QA',
            'language': 'EN',
            'overall_score': 0.3,
            'high_count': 0,
            'med_count': 1,
            'low_count': 0,
            'flags': [
                {
                    'category': 'Compliance',
                    'severity': 'Medium',
                    'issue': 'Smoke test issue',
                    'rationale': 'Smoke test rationale',
                    'flag_key': 'smoke-compliance-1',
                    'confidence': 0.8,
                    'impact': 5,
                    'likelihood': 5,
                    'citations': [
                        {
                            'doc_title': 'Smoke Doc',
                            'page': 1,
                            'source_type': 'external',
                            'policy_reference': 'Data minimization requirement',
                            'language': 'EN',
                        }
                    ],
                }
            ],
        }
    else:
        base = os.getenv('LOGICAPP_READER_SERVER_URL', '')
        sig = os.getenv('LOGICAPP_READER_SIG', '')
        payload = {'project_number': 'SMOKE-001', 'top_n': 5}

    if not base or not sig:
        print('Missing callback URL/signature env vars for selected mode.')
        return 1

    response = invoke(base, sig, payload)
    print('status_code:', response.status_code)
    try:
        body = response.json()
    except Exception:
        body = {'raw': response.text[:500]}
    print(json.dumps(body, indent=2))
    return 0 if response.ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
