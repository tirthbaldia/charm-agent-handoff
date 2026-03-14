# Operations

## Monitoring
- Logic App runs: success/failure by workflow.
- SQL connectivity and procedure error rates.
- Foundry agent response quality and error telemetry.

## Routine Checks
- Daily: failed Logic App runs and callback status.
- Weekly: SQL row growth and drift/consistency metrics.
- Monthly: rotate callback signatures/keys and review access policies.

## Incident Response
1. Identify failure layer (Teams/Foundry/LogicApp/SQL).
2. Capture correlation IDs from Logic App run history.
3. Validate SQL connection status and firewall/credentials.
4. Re-run `scripts/smoke_logicapps.py` with controlled payload.
5. Apply rollback scripts/workflow versions if needed.

## Backup/Recovery
- Keep workflow JSON and SQL scripts versioned in Git.
- Export Foundry agent versions before major changes.
- Maintain database backup policy in customer tenant.
