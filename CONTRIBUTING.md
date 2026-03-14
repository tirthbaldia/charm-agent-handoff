# Contributing

## Branching
- Create branches from `main`.
- Use non-breaking, reviewable commits.

## Required checks
- `python3 scripts/validate_placeholders.py`
- `python3 app/fastapi/validate_config.py`
- SQL files keep UTF-8 + LF.

## Security rules
- Never commit live keys, callback signatures, tenant IDs, or connection strings.
- Keep all environment values as placeholders in tracked files.

## Pull request checklist
- [ ] Updated docs for behavior/config changes
- [ ] Placeholder scan passes
- [ ] Any new secrets documented in `config/.env.example` only as placeholder
