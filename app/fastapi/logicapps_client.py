from __future__ import annotations

from typing import Any
import httpx


def _build_invoke_url(base: str, sig: str) -> str:
    return (
        f"{base}/invoke"
        f"?api-version=2019-05-01"
        f"&sp=/triggers/When_an_HTTP_request_is_received/run"
        f"&sv=1.0"
        f"&sig={sig}"
    )


async def invoke_logger(base: str, sig: str, payload: dict[str, Any]) -> dict[str, Any]:
    url = _build_invoke_url(base, sig)
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(url, json=payload)
        resp.raise_for_status()
        return resp.json() if resp.content else {'status': 'ok'}


async def invoke_reader(base: str, sig: str, payload: dict[str, Any]) -> dict[str, Any]:
    url = _build_invoke_url(base, sig)
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(url, json=payload)
        resp.raise_for_status()
        return resp.json() if resp.content else {'status': 'ok'}
