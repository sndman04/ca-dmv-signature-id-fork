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
Swift outcome: failed / signatureMismatch
Matching stages: aamva-applicability, vcb-discovery, cborld-decode, credential-validation, aamva-protected-data, did-resolution
First divergence stage: data-integrity-vcb
Blocking: yes
Security exception: none
Notes: Raw payload and decoded identity data are not stored. The observed AAMVA optical hash matched the JS reference output, which points to legacy handbuilt Data Integrity canonicalization as the likely divergence source.
```

## Phase Status

Phase 0 is complete.

Phase 1 is complete.

Phase 2 is next.

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
