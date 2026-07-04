# Final Review Notes

This review records the current implementation state after focused bug, security, and documentation passes.

## Blocking Bugs Reviewed

- Official valid DMV UAT fixture verifies as `.verified` with status checking disabled.
- Official invalid DMV UAT fixture returns `.failed`.
- Tampered protected AAMVA field returns `.failed`.
- UAT fixture in production mode returns `.failed`.
- Missing required VCB returns `.failed`.
- Optional missing VCB before the requirement date returns `.notPresent`.
- Malformed base64 and malformed CBOR-LD return `.failed`.
- Oversized CBOR byte/text length and array/map count declarations are rejected before allocating collection storage.
- Unsupported CBOR indefinite-length, simple-value, float, break-code, negative-overflow, and trailing-byte encodings fail closed.
- Status-required official UAT verification returns `.unavailable`, not `.verified`, because the live UAT status endpoint is not currently usable.
- Synthetic JS-reference Bitstring Status List credentials verify with `ecdsa-rdfc-2019`; verified set bits map to `.revoked`, and verified clear bits map to `.verified`.
- Credential expiration data is enforced after signature verification and after any required revocation check succeeds as not revoked.

## Security/Safety Review

- No production logging APIs are used in the verifier.
- Public result messages do not include raw barcode data, parsed AAMVA fields, proof values, or decoded credentials.
- DID Web resolution uses explicit DMV URLs for production and UAT modes.
- Status-list fetches use explicit DMV API host allowlists and suppress redirects.
- Status-list credential parsing rejects unsupported fields and unsafe strings before native N-Quads generation, while accepting the standard optional fields observed on live production status lists.
- SPI-only status-list profile diagnostics report unknown key names for development triage when DMV status-list shapes drift, while public verification still fails closed as `.unavailable`.
- The public API does not expose parsed identity fields.
- Debug/inspection fields are SPI-only for the self-test runner.

## Documentation Review

Added or updated:

- `README.md`
- `Docs/API.md`
- `Docs/SECURITY_AND_PRIVACY.md`
- `Docs/THREAT_MODEL.md`
- `Docs/TECHNICAL_GUIDE_REVIEW.md`
- `Docs/DEPENDENCY_AND_LICENSE_AUDIT.md`
- `Docs/UPSTREAM_TRACKING.md`
- `Docs/CI.md`
- `Docs/INTEGRATION.md`
- `NOTICE`

## Release Audit

`Tools/final-release-audit.sh` is the aggregate pre-release gate. It runs debug and release builds, SwiftPM tests, fixture self-test, parity status, JavaScript reference oracle smoke checks, replacement readiness, conformance report freshness, and security-exception inventory checks.

## Supported-Scope Limitation

The default verifier uses `NativeSwiftJSONLDCanonicalizationEngine`, a native Swift DMV-profile JSON-LD/RDF canonicalization path. It is typed and parity-tested against the current DMV fixture corpus and the selected JavaScript SDK baseline. It is intentionally not a general JSON-LD/Data Integrity SDK; unsupported signed data outside the DMV profile and parity-tested safe extension subset fails closed.

The live UAT status URL derived from the official valid fixture currently redirects to a host outside the original SDK allowlist and returns 404 after redirect. The verifier therefore keeps the official status-required UAT sample at `.unavailable` even though the supported status-list credential proof and bit-check path is implemented and covered by synthetic JS-reference data.
