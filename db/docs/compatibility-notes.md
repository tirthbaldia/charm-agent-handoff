# UC1 Compatibility Notes

## Citation Model Change
- Current citation contract uses: `doc_title`, `page`, `source_type`, `policy_reference`, `language`.
- Legacy fields `source_url`, `requirement_id`, and `clause_id` were removed from `uc1.Citation`.
- For legacy data upgrades, use `db/sql/05_uc1_upgrade_policy_reference_and_reviewrun_backfill.sql`.

## ReviewRun Reliability Change
- `content_hash` is now populated from canonical finalized run content.
- `baseline_run_id` is now guaranteed:
  - first run for a project points to itself
  - later runs point to the previous finalized run

## Metadata Snapshot Caveat
- Some text snapshots in this folder were exported before this migration.
- For deployment truth, treat `db/sql/*.sql` as authoritative.
