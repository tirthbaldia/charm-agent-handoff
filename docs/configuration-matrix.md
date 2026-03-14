# Configuration Matrix

| Placeholder | Used In | Owner |
|---|---|---|
| `${AZURE_SUBSCRIPTION_ID}` | Bicep, logic app resource IDs | Client cloud admin |
| `${AZURE_TENANT_ID}` | Agent/infra metadata | Client cloud admin |
| `${AZURE_RESOURCE_GROUP}` | Logic App/infra references | Client cloud admin |
| `${AZURE_LOCATION}` | Infra and workflow location | Client cloud admin |
| `${FOUNDRY_PROJECT_ENDPOINT}` | Agent runtime config | AI platform owner |
| `${FOUNDRY_MODEL_DEPLOYMENT_NAME}` | Agent model binding | AI platform owner |
| `${VECTOR_STORE_ID}` | File search tool | AI platform owner |
| `${MEMORY_STORE_NAME}` | Memory search tool | AI platform owner |
| `${LOGICAPP_LOGGER_SERVER_URL}` | Logger OpenAPI server | Integration owner |
| `${LOGICAPP_READER_SERVER_URL}` | Reader OpenAPI server | Integration owner |
| `${LOGICAPP_LOGGER_SIG}` | Logger callback auth | Integration owner |
| `${LOGICAPP_READER_SIG}` | Reader callback auth | Integration owner |
| `${SQL_SERVER_FQDN}` | Workflow SQL dataset path | DBA |
| `${SQL_DATABASE_NAME}` | Workflow SQL dataset path | DBA |
| `${SQL_USERNAME}` / `${SQL_PASSWORD}` | Runtime/tests | DBA |
