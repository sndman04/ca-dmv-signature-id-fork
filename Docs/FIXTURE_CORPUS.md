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
- Runtime-generated JS/Swift parity cases for signed VCB credentials with no status, `credentialStatus`, `validFrom`/`validUntil`, combined status plus validity dates, root/subject/status node IDs, signed proof `expires` values including a past proof timestamp that remains JS-verified, alternate `proofValue` encodings, tampered proof signatures, tampered proof metadata (`created`, `expires`, and `verificationMethod`), and tampered protected AAMVA data.
- Deterministic mutation parity cases for malformed VCB base64, truncated VCB CBOR-LD, and corrupted compressed VCB values, comparing JS and Swift failure-stage mapping, issuer applicability, VCB requirement policy, decoded VCB byte counts, and absence of signature inputs without storing private payloads.
- Runtime-generated JS/Swift status-list verify-data parity cases for the base status-list credential, optional live-style VC fields, and safe absolute-IRI extension terms on the status-list root, credentialSubject, and proof.
- Runtime-generated JS/Swift status-list bit boundary parity cases for revoked bits, clear bits, byte-boundary indexes, the last bit in a short list, and out-of-range handling.
- Runtime-generated shape-by-shape status-list extension matrix parity cases for status-list document/proof canonical N-Quads and verify-data, covering safe absolute-IRI extension terms on the root, credentialSubject, and proof.
- Runtime-generated JS/Swift canonical N-Quads parity cases for safe absolute-IRI extension terms in VCB documents and Data Integrity proof configs, including explicit blank-node `@id`, generic node-object `@type`, `@reverse`, `@graph`, `@included`, `@nest`, directed `@value`, `@json` value objects, scalar and array `@set`/`@list` values, generated blank-node reverse subjects, generated blank-node `@included` nodes, and string `@index` values.
- Runtime-generated shape-by-shape JSON-LD extension matrix parity cases for VCB document and Data Integrity proof canonical N-Quads, covering literals, arrays, node references, explicit and generated blank nodes, reverse properties, named graphs, included nodes, nested properties, value objects, sets, and lists including empty lists.
- Runtime-generated canonicalization engine differential cases for VCB document, VCB proof, status-list document, status-list proof, and official valid/invalid UAT VCB document/proof canonicalization, including a compact unknown field rejection check so the replacement engine contract covers both byte-identical accepted output and fail-closed behavior. The same covered canonicalization cases also compare the production selector against the supported-profile regression baseline.
- Release-audit gate coverage through `Tools/final-release-audit.sh`, which runs the committed fixture/parity gates, checks replacement readiness, verifies conformance report freshness, and fails if accepted security exceptions are present without inventory review.
- Generated unknown CBOR-LD behavior coverage: JS-accepted text-key unknowns are preserved, unknown compressed numeric term ids are rejected, safe absolute-IRI extensions canonicalize generically, and compact unknown terms fail closed in parity with reference safe-mode canonicalization.
- Synthetic CBOR parser hardening coverage for duplicate map keys, oversized byte/text lengths, oversized array/map counts, unsupported indefinite-length encodings, unsupported simple/float values, negative integer overflow, and trailing top-level bytes.
- Redacted production parity mismatch tracking without private payload data.

Documented gaps:

- None currently recorded in the fixture manifest.

Any future documented gap may satisfy Phase 2 inventory requirements temporarily, but it does not satisfy the final project requirement that nothing remain skipped or deferred. Documented gaps must be converted into generated or committed test coverage before the long-term replacement is complete.

## Validation

`FixtureManifestTests` enforces:

- every required Phase 2 category appears in the manifest;
- the manifest does not contain raw PDF417 data, parsed AAMVA data, or proof values;
- documented gaps include explicit reasons.
