# FastAPI Utility Layer

This is a support/fallback service for operations and parity testing.

## Endpoints
- `GET /healthz`
- `GET /config/validate`
- `POST /parity/logger`
- `POST /parity/reader`

## Run
```bash
cd app/fastapi
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8080
```
