# Database Assets

- `sql/`: deploy scripts for schema, upgrade/backfill, procedures, views, smoke tests.
- `docs/`: metadata snapshots from live environment for validation.

Apply scripts in deterministic order:
1. `00_uc1_schema_tables_constraints_indexes.sql` (fresh build only)
2. `05_uc1_upgrade_policy_reference_and_reviewrun_backfill.sql` (in-place upgrade/backfill)
3. `10_uc1_procedures.sql`
4. `20_uc1_views.sql`
5. `30_uc1_smoke_tests.sql`

Current citation contract:
- `doc_title`, `page`, `source_type`, `policy_reference`, `language`
- Legacy fields `source_url`, `requirement_id`, and `clause_id` are removed.
