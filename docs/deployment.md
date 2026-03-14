# Deployment Guide

## 1) Infrastructure
Deploy Bicep templates:
```bash
az deployment sub create \
  --name charm-handoff-dev \
  --location "${AZURE_LOCATION}" \
  --template-file infra/bicep/main.bicep \
  --parameters @infra/bicep/parameters/dev.bicepparam
```

## 2) SQL Schema
Apply scripts in order:
1. `db/sql/00_uc1_schema_tables_constraints_indexes.sql`
2. `db/sql/10_uc1_procedures.sql`
3. `db/sql/20_uc1_views.sql`
4. `db/sql/30_uc1_smoke_tests.sql`

## 3) Logic Apps
- Deploy or update workflow definitions in `logicapps/`.
- Bind SQL API connection `${SQL_API_CONNECTION_NAME}`.
- Regenerate callback URLs/signatures and update env values.

## 4) Foundry Agent
- Prompt: `agents/charm/system_prompt.md`
- Tools: `agents/charm/tools/*.openapi.json`
- Model deployment: `${FOUNDRY_MODEL_DEPLOYMENT_NAME}`

## 5) Teams Publish
- Publish from Foundry to Teams.
- Run E2E smoke test (new review + history request).
