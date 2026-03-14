# Security Policy

## Supported versions
This repository is a hand-off pack; latest `main` is supported.

## Reporting a vulnerability
Please report privately to repository maintainers.
Do not open public issues for credential leaks or exploitable misconfigurations.

## Secrets handling
- No live secrets in repository.
- All runtime secrets must be provided by customer-owned Key Vault and environment configuration.
- Rotate credentials if there is any suspicion of exposure.
