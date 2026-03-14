from __future__ import annotations

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from settings import Settings, validate_env
from logicapps_client import invoke_logger, invoke_reader

app = FastAPI(title='Charm Handoff Utility API', version='1.0.0')
settings = Settings()


class LoggerPayload(BaseModel):
    payload: dict


class ReaderPayload(BaseModel):
    payload: dict


@app.get('/healthz')
async def healthz() -> dict:
    return {'status': 'ok'}


@app.get('/config/validate')
async def config_validate() -> dict:
    return validate_env()


@app.post('/parity/logger')
async def parity_logger(req: LoggerPayload) -> dict:
    try:
        result = await invoke_logger(
            base=settings.logicapp_logger_server_url,
            sig=settings.logicapp_logger_sig,
            payload=req.payload,
        )
        return {'ok': True, 'result': result}
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f'logger invoke failed: {exc}') from exc


@app.post('/parity/reader')
async def parity_reader(req: ReaderPayload) -> dict:
    try:
        result = await invoke_reader(
            base=settings.logicapp_reader_server_url,
            sig=settings.logicapp_reader_sig,
            payload=req.payload,
        )
        return {'ok': True, 'result': result}
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f'reader invoke failed: {exc}') from exc
