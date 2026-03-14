# Sanitization Policy

## Objective
Keep repository public-safe while preserving reproducible deployment patterns.

## Must be placeholders
- API keys, passwords, tokens
- Logic App callback signatures
- Subscription/tenant identifiers when tied to active tenant
- Resource IDs and environment endpoints
- Vector/memory store IDs from active environment

## Allowed
- Generic architecture metadata
- Non-sensitive schema and workflow logic
- Static documentation and sample payloads

## Rotation Requirement
Before client go-live, rotate any pre-existing secrets used during prototyping.
