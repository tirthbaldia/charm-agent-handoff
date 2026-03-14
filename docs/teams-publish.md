# Teams Publish Runbook (Foundry Direct)

## Goal
Publish the Foundry `Charm` agent to Teams while keeping all definitions in this repository.

## Steps
1. Open Azure AI Foundry project (`${FOUNDRY_PROJECT_NAME}`).
2. Update/paste system instructions from `agents/charm/system_prompt.md`.
3. Recreate/update tools using:
   - `agents/charm/tools/log_review_to_sql.openapi.json`
   - `agents/charm/tools/read_reviews_from_sql.openapi.json`
4. Configure tool endpoint/signature values from customer environment.
5. Validate with smoke prompts:
   - New review logs successfully.
   - History retrieval returns rows.
6. Publish agent to Teams from Foundry.

## Required Configuration
- Model deployment: `${FOUNDRY_MODEL_DEPLOYMENT_NAME}`
- Tool server URLs and signatures
- Vector store and memory store IDs (if enabled)

## Acceptance Criteria
- Teams user can run review and receive response.
- SQL receives review run/flags/citations.
- History query from Teams returns expected rows.
