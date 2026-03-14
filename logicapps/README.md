# Logic Apps Workflows

- `la-mck-uc1-logger.workflow.json`: Receives review payload and logs run/flags/citations to SQL (`policy_reference` citation model).
- `la-mck-uc1-reader.workflow.json`: Reads review history from SQL.

These files are sanitized from live exports and use placeholders.
Update `${...}` values during deployment.
