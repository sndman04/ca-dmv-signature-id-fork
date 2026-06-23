# Security and Privacy

This package handles raw PDF417 barcode data from government identity documents. That data can contain personally identifiable information and must be treated as sensitive.

## Core Rules

- Never log raw PDF417 data.
- Never log parsed AAMVA fields.
- Never log decoded credentials by default.
- Never persist raw barcode data inside the verifier package.
- Never persist parsed PII inside the verifier package.
- Keep public results privacy-minimized.
- Fail closed on unsupported or malformed verification data.
- Restrict network access to DMV-controlled hosts for the selected mode.

## Current Implementation Status

The package currently parses AAMVA data, decodes the DMV VCB credential shape covered by the official UAT samples, resolves DMV DID Web documents, verifies `ecdsa-xi-2023` signatures for that profile, and verifies `ecdsa-rdfc-2019` Bitstring Status List credentials for the supported DMV VC v2 status-list profile.

When status checking is required but DMV status infrastructure is unavailable or returns unsupported data, the verifier returns `.unavailable` rather than `.verified`.

## Debugging Policy

Debug details are not exposed in the public API yet. When added, debug output must be:

- Explicitly opt-in.
- Clearly documented as sensitive.
- Redacted by default.
- Designed so production integrations cannot accidentally log PII.

## Fixture Policy

Do not commit real ID data.

Allowed fixtures:

- DMV-published samples whose redistribution is permitted.
- Synthetic AAMVA data created only for tests.
- Redacted byte-level fixtures that contain no real PII.

Disallowed fixtures:

- Real scans from real driver licenses or ID cards.
- Photos or screenshots of real identity documents.
- Debug output containing decoded real credential data.
