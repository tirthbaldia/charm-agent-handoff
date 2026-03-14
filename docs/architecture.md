# Architecture

## End-to-End Flow
1. User sends request in Teams.
2. Foundry-hosted `Charm` agent evaluates proposal using prompt + knowledge tools.
3. Agent calls `log_review_to_sql` OpenAPI tool (Logic App logger).
4. Logger workflow executes SQL procedures (`UpsertReview`, `UpsertFlag`, `AddCitation`, `FinalizeReview`).
5. Agent calls `read_reviews_from_sql` when history is requested.
6. Power BI reads curated SQL views for dashboarding.

## Primary Components
- **Foundry Project**: Agent runtime and tool binding.
- **Logic Apps**: HTTP trigger tools for SQL write/read.
- **Azure SQL**: `uc1` schema as system of record.
- **App Insights + Log Analytics**: Monitoring.
- **Teams**: User channel.

## Source of Truth
- Prompt: `agents/charm/system_prompt.md`
- Tool contracts: `agents/charm/tools/*.openapi.json`
- Workflows: `logicapps/*.workflow.json`
- Data model: `db/sql/*.sql`
- Provisioning: `infra/bicep/*`
