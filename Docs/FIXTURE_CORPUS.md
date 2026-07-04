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
- Runtime-generated JS/Swift status-list verify-data parity cases for the base status-list credential, optional live-style VC fields, and safe absolute-IRI extension terms on the status-list root, credentialSubject, and proof.
- Runtime-generated JS/Swift canonical N-Quads parity cases for safe absolute-IRI extension terms in VCB documents and Data Integrity proof configs, including explicit blank-node `@id`, generic node-object `@type`, `@reverse`, `@graph`, `@included`, `@nest`, directed `@value`, `@json` value objects, and string `@index` values.
- Runtime-generated canonicalization engine differential cases for VCB document, VCB proof, status-list document, status-list proof, and official valid/invalid UAT VCB document/proof canonicalization, including a compact unknown field rejection check so the replacement engine contract covers both byte-identical accepted output and fail-closed behavior.
- Generated unknown CBOR-LD behavior coverage: JS-accepted text-key unknowns are preserved, unknown compressed numeric term ids are rejected, safe absolute-IRI extensions canonicalize generically, and compact unknown terms fail closed in parity with reference safe-mode canonicalization.
- Redacted production parity mismatch tracking without private payload data.

Documented gaps:

- None currently recorded in the fixture manifest.

Any future documented gap may satisfy Phase 2 inventory requirements temporarily, but it does not satisfy the final project requirement that nothing remain skipped or deferred. Documented gaps must be converted into generated or committed test coverage before the long-term replacement is complete.

## Validation

`FixtureManifestTests` enforces:

- every required Phase 2 category appears in the manifest;
- the manifest does not contain raw PDF417 data, parsed AAMVA data, or proof values;
- documented gaps include explicit reasons.
