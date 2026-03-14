.PHONY: validate sanitize rebuild-assets smoke-logger smoke-reader

validate:
	python3 scripts/check_export_snapshot.py
	python3 scripts/check_sql_static.py
	python3 scripts/check_docs_links.py
	python3 scripts/validate_placeholders.py
	python3 app/fastapi/validate_config.py || true

rebuild-assets:
	python3 scripts/build_sanitized_assets.py

smoke-logger:
	python3 scripts/smoke_logicapps.py logger

smoke-reader:
	python3 scripts/smoke_logicapps.py reader
