# Bicep Infrastructure Pack

This folder provisions a customer-owned baseline stack:
- Azure AI Services (Foundry account + project resource)
- Azure SQL Server + Database + firewall baseline
- Logic Apps + SQL API connection scaffolding
- Key Vault
- Log Analytics + Application Insights

## Deploy
```bash
az deployment sub create \
  --name charm-handoff-dev \
  --location canadacentral \
  --template-file infra/bicep/main.bicep \
  --parameters @infra/bicep/parameters/dev.bicepparam
```

Then import workflow definitions from `logicapps/` and apply SQL scripts from `db/sql/`.
