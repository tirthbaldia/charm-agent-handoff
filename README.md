# charm-agent-handoff

Customer-owned hand-off package for the UC1 Charm solution.

This repository externalizes the production setup from Azure AI Foundry UI into source-controlled assets:
- Agent prompt and definition snapshot
- OpenAPI tool contracts
- Logic App workflow definitions
- Azure SQL schema/procedures/views
- Azure provisioning templates (Bicep)
- Operational runbooks and onboarding docs

## Runtime Model
- Primary runtime: **Foundry agent published to Teams**
- Tool runtime: **Azure Logic Apps** (`logger` and `reader`)
- Data layer: **Azure SQL** (`uc1` schema)
- Reporting: **Power BI** over SQL views

## Repository Layout
- `agents/`: Agent prompt, manifest, tool contracts
- `logicapps/`: Deployable workflow definitions
- `db/`: SQL deploy scripts and object inventory
- `infra/bicep/`: Infrastructure-as-code templates
- `app/fastapi/`: Utility/fallback API service
- `config/`: Environment variable and settings templates
- `scripts/`: Validation and smoke scripts
- `docs/`: Architecture, deployment, operations, onboarding

## Quick Start
1. Copy `config/.env.example` to `.env` and populate values.
2. Validate placeholders and config:
   - `python3 scripts/validate_placeholders.py`
   - `python3 app/fastapi/validate_config.py`
3. Review deployment guide: `docs/deployment.md`
4. Publish/update agent in Foundry using:
   - `agents/charm/system_prompt.md`
   - `agents/charm/tools/*.openapi.json`

## Security
- This repo contains **no live credentials**.
- All environment-specific values are placeholders.
- Before production cutover, rotate any previously used callback signatures/keys.

See `docs/sanitization-policy.md` and `docs/public-release-checklist.md`.
