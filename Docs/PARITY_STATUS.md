# Parity Status

This document tracks privacy-safe JavaScript/Swift parity status for the long-term replacement effort.

Do not record raw PDF417 payloads, decoded AAMVA fields, names, dates of birth, addresses, proof values, DID documents, or status-list contents here.

## Dashboard Fields

Each parity record should use this shape:

```text
Fixture ID:
Fixture class: official | synthetic | redacted-vector | local-only
Storage level: committed | encrypted-local-only | prohibited
JS SDK baseline:
JS outcome:
Swift outcome:
Matching stages:
First divergence stage:
Blocking: yes | no
Security exception: none | <id>
Notes:
```

Allowed stage names:

- `aamva-applicability`
- `vcb-discovery`
- `cborld-decode`
- `credential-validation`
- `aamva-protected-data`
- `did-resolution`
- `data-integrity-vcb`
- `status-url`
- `status-fetch`
- `data-integrity-status-list`
- `status-bit`
- `expiration`
- `public-result-mapping`

## Current Records

```text
Fixture ID: production-redacted-vector-001
Fixture class: redacted-vector
Storage level: prohibited
JS SDK baseline: local reference checkout at 03c5485513ff6f2de6b46950a159b8f2cd427859
JS outcome: verified
Swift outcome: verified
Matching stages: aamva-applicability, vcb-discovery, cborld-decode, credential-validation, aamva-protected-data, did-resolution, data-integrity-vcb
First divergence stage: none
Blocking: no
Security exception: none
Notes: Raw payload and decoded identity data are not stored. The original observed AAMVA optical hash matched the JS reference output, which isolated the issue to the VCB Data Integrity canonicalization path. Rechecked locally in memory after deriving VCB document blank-node labels from the RDF graph instead of hardcoding them; JS and Swift now both verify this vector.
```

## Phase Status

Phase 0 is complete.

Phase 1 is complete.

Phase 2 is complete.

Phase 3 is complete.

Phase 4 is in progress.

Completed:

- Long-term one-to-one JS parity plan created.
- Main planning document links to the long-term parity plan.
- Current handbuilt VCB and status-list proof verification paths are isolated behind `LegacyHandbuiltDataIntegrityEngine`.
- Legacy handbuilt N-Quads paths are labeled as replacement targets.
- Privacy-safe parity dashboard format created.
- Known production parity mismatch recorded as a redacted vector without raw barcode or PII.

Completed Phase 0 gates:

- Build and tests pass with no warnings.
- Phase 0 changes committed and pushed.

Completed Phase 1 work:

- `Tools/reference-runner.mjs` supports existing official fixture summary mode.
- `Tools/reference-runner.mjs --stdin` accepts raw payloads from stdin and emits privacy-minimized JSON.
- `Tools/reference-oracle-smoke.sh` can run oracle smoke checks when Node and reference SDK dependencies are installed, or explicitly report a skip when they are unavailable.
- `CADMVVerifierOracle` emits privacy-minimized Swift verifier summaries for stdin payloads.
- `Tools/parity-compare.mjs` compares Swift and JS summaries for committed official UAT fixtures.

Completed Phase 1 gates:

- Commit and push completed Phase 1.

Completed Phase 2 work:

- Added `Tests/CADMVVerifierTests/Fixtures/fixture-manifest.json`.
- Added `Docs/FIXTURE_CORPUS.md`.
- Added manifest validation tests for required categories and privacy constraints.

Completed Phase 2 gates:

- Build and tests pass with no warnings.
- Phase 2 changes committed and pushed.

Completed Phase 3 work:

- Added `Docs/CBORLD_REGISTRY_AUDIT.md`.
- Expanded `Tools/parity-compare.mjs` to compare VCB byte length and privacy-safe credential profile fields.

Completed Phase 3 gates:

- Build and parity checks pass with no warnings.
- Phase 3 changes committed and pushed.

Completed Phase 4 work:

- Replaced hardcoded VCB document blank-node label ordering with deterministic graph-derived labels for the supported DMV credential graph.
- Routed VCB proof, status-list proof, and status-list document canonicalization through structured RDF terms and the shared N-Quads renderer instead of raw string assembly.
- Added synthetic regression coverage for the observed production class where status-list and subject blank nodes can swap canonical order based on credential content.
- Added exact-output proof canonicalization tests for optional `created` and `expires` handling, plus fail-closed coverage for ambiguous blank-node hashes.
- Rechecked the prohibited-storage production vector locally in memory; the previous `data-integrity-vcb` divergence is resolved without committing raw payloads or PII.

Remaining Phase 4 gates:

- Replace the remaining profile-specific graph construction with the selected standards-grade or native-library-backed JSON-LD/RDF canonicalization engine.
- Add reference-equivalent canonical N-Quads or verify-data comparisons for the full committed fixture corpus.
- Document memory-safety, license, build, and platform implications if the final engine uses a native-library bridge.
