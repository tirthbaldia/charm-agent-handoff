# Database Assets

- `sql/`: deploy scripts for schema, procedures, views, smoke tests.
- `docs/`: metadata snapshots from live environment for validation.

Apply scripts in deterministic order:
1. `00_uc1_schema_tables_constraints_indexes.sql`
2. `10_uc1_procedures.sql`
3. `20_uc1_views.sql`
4. `30_uc1_smoke_tests.sql`
