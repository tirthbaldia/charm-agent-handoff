# Client Onboarding Checklist

## Prerequisites
- [ ] Azure subscription and tenant access
- [ ] Foundry project and model deployment ready
- [ ] SQL server/database provisioned
- [ ] Key Vault configured for secrets
- [ ] Teams publishing permissions available

## Configuration
- [ ] Fill `.env` from `config/.env.example`
- [ ] Set Logic App callback URLs/signatures
- [ ] Validate placeholders: `python3 scripts/validate_placeholders.py`
- [ ] Validate config: `python3 app/fastapi/validate_config.py`

## Deployment
- [ ] Deploy infra with Bicep (`infra/bicep`)
- [ ] Apply SQL scripts in order (`db/sql`)
- [ ] Deploy logic app workflows (`logicapps`)
- [ ] Configure Foundry agent prompt + tools from `agents/charm`

## Verification
- [ ] Logger smoke test passes
- [ ] Reader smoke test passes
- [ ] Teams E2E scenario passes
- [ ] Power BI visuals reflect new reviews
