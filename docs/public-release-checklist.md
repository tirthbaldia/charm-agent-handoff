# Public Release Checklist

- [ ] `scripts/validate_placeholders.py` passes
- [ ] No known secret patterns in git diff
- [ ] No live callback signatures (`sig=`) in JSON/YAML/MD
- [ ] No active subscription or tenant UUIDs from prototype tenant
- [ ] All env-specific values documented in `config/.env.example`
- [ ] Tool specs point to placeholders, not live endpoints
- [ ] Documentation reviewed for accidental screenshots with sensitive data
