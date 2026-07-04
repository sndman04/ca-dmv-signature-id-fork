# Fixture Corpus

This project uses a privacy-first fixture corpus. Real barcode payloads from real identity documents must not be committed.

The machine-readable manifest is:

```text
Tests/CADMVVerifierTests/Fixtures/fixture-manifest.json
```

## Storage Levels

- `committed`: Redistributable official fixture or non-PII metadata committed to the repository.
- `generated`: Synthetic fixture created deterministically by tests or self-test code.
- `redacted-vector`: Privacy-safe record derived from a real observation without raw PDF417 data, decoded identity fields, proof values, or parsed PII.
- `local-only`: Developer-only input that must not be committed.
- `documented-gap`: Required coverage category that has an explicit reason for not being materialized yet.

## Current Coverage

The manifest maps required Phase 2 corpus categories to official fixtures, synthetic generated fixtures, redacted vectors, or documented gaps.

Current committed/generated coverage includes:

- Official valid and invalid UAT fixtures from the reference SDK.
- Synthetic AAMVA parser and malformed-input cases, including DL and ID primary identity subfiles.
- Synthetic CBOR-LD decode and validation cases.
- Synthetic DID/network failure cases.
- Synthetic status-list and expiration cases.
- Runtime-generated JS/Swift parity cases for signed VCB credentials with no status, `credentialStatus`, `validFrom`/`validUntil`, combined status plus validity dates, alternate `proofValue` encodings, tampered signatures, and tampered protected AAMVA data.
- Redacted production parity mismatch tracking without private payload data.

Documented gaps:

- `unknown-ignorable-cborld-values`: JS behavior is characterized and Swift preserves JS-accepted text-encoded unknown signed fields internally. Safe absolute-IRI extension terms now canonicalize generically, but compact unknown terms still need final standards-grade coverage instead of failing closed.

These documented gaps satisfy Phase 2 inventory requirements, but they do not satisfy the final project requirement that nothing remain skipped or deferred. They must be converted into generated or committed test coverage before the long-term replacement is complete.

## Validation

`FixtureManifestTests` enforces:

- every required Phase 2 category appears in the manifest;
- the manifest does not contain raw PDF417 data, parsed AAMVA data, or proof values;
- documented gaps include explicit reasons.
