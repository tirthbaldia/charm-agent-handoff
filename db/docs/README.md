# DB Object Inventory

This directory contains exported object metadata from the UC1 schema to support hand-off validation:
- tables, views, procedures
- constraints, indexes, parameters
- result-shape snapshots for reporting procedures/views

Use alongside `db/sql/*.sql` to validate that deployed objects match expected structure.
For post-migration behavior changes, see `compatibility-notes.md`.
