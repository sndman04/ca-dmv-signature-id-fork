# Conformance Report

Generated: 2026-07-04T02:38:08.071Z
Repository revision: `a392c6d`
Reference SDK: `cadmv-dlid-verifier-sdk@0.0.1-0`

This report is generated from committed non-PII fixtures and synthetic cases. It does not include raw PDF417 payloads, decoded identity fields, or real private scan data.

Overall result: PASS

## Gate Summary

| Gate | Command | Cases | Result |
| --- | --- | ---: | --- |
| Official UAT Fixture Parity | `node Tools/parity-compare.mjs` | 2 | PASS |
| Generated Signature Parity | `node Tools/generated-signature-parity.mjs` | 8 | PASS |
| Status-List Verify-Data And N-Quads Parity | `node Tools/status-list-parity.mjs` | 3 | PASS |
| Generic VCB JSON-LD Extension N-Quads Parity | `node Tools/generic-jsonld-extension-parity.mjs` | 1 | PASS |
| Generic Proof JSON-LD Extension N-Quads Parity | `node Tools/generic-proof-extension-parity.mjs` | 1 | PASS |
| JSON-LD 1.1 Behavior Characterization | `node Tools/jsonld-behavior-characterization.mjs` | 12 | PASS |
| Canonicalization Engine Differential | `node Tools/canonicalization-engine-differential.mjs` | 5 | PASS |
| W3C RDFC-1.0 Conformance Subset | `Tools/swift-test.sh --filter RDFDatasetCanonicalizerTests/testW3CRDFC10ConformanceSubset` | 1 | PASS |
| W3C RDFC-1.0 Issued-Identifier Map Subset | `Tools/swift-test.sh --filter RDFDatasetCanonicalizerTests/testW3CRDFC10IssuedIdentifierMapSubset` | 1 | PASS |
| W3C RDFC-1.0 Negative Clique Fail-Closed Coverage | `Tools/swift-test.sh --filter RDFDatasetCanonicalizerTests/testW3CRDFC10NegativeCliqueGraphFailsClosed` | 1 | PASS |

## Covered Cases

### Official UAT Fixture Parity

- Result: PASS
- Compared cases: 2
- Duration: 2410 ms
- Case IDs:
  - `official-valid-uat`
  - `official-invalid-uat`

### Generated Signature Parity

- Result: PASS
- Compared cases: 8
- Duration: 6020 ms
- Case IDs:
  - `generated-valid-z-signature`
  - `generated-valid-u-signature`
  - `generated-valid-with-status-signature`
  - `generated-valid-with-validity-dates-signature`
  - `generated-valid-with-status-and-validity-dates-signature`
  - `generated-expired-valid-signature`
  - `generated-tampered-proof-signature`
  - `generated-tampered-protected-aamva-field`

### Status-List Verify-Data And N-Quads Parity

- Result: PASS
- Compared cases: 3
- Duration: 4945 ms
- Case IDs:
  - `synthetic-status-list-base`
  - `synthetic-status-list-optional-fields`
  - `synthetic-status-list-absolute-iri-extensions`
- Notes:
  - synthetic-status-list-base: document N-Quads SHA-256 32f9e3eb0ef441494d9f35b40deed3703c7730e491db83245714e0a1475100c1; proof N-Quads SHA-256 93fa093cba64513885ce626317a174530e4d19527212094b1571d4b8e665a221
  - synthetic-status-list-optional-fields: document N-Quads SHA-256 754ba90533e8d44df66599957c68a3f9f2cccac0f1380c538f17926967783567; proof N-Quads SHA-256 93fa093cba64513885ce626317a174530e4d19527212094b1571d4b8e665a221
  - synthetic-status-list-absolute-iri-extensions: document N-Quads SHA-256 1d15024c7b48d02e11025b4a029596abc10e2a7b2b07b25f4f17c9ade58d0944; proof N-Quads SHA-256 ec9fbce00e29e40b866166154710d56d30addd0b536573065f2a8552ce80a6ed

### Generic VCB JSON-LD Extension N-Quads Parity

- Result: PASS
- Compared cases: 1
- Duration: 555 ms
- Case IDs:
  - `generic-jsonld-extension-values`

### Generic Proof JSON-LD Extension N-Quads Parity

- Result: PASS
- Compared cases: 1
- Duration: 565 ms
- Case IDs:
  - `generic-proof-extension-values`

### JSON-LD 1.1 Behavior Characterization

- Result: PASS
- Compared cases: 12
- Duration: 6027 ms
- Case IDs:
  - `implemented-absolute-id-node`
  - `implemented-nested-graph`
  - `implemented-json-literal`
  - `fail-closed-relative-id-node`
  - `fail-closed-blank-node-id`
  - `fail-closed-nested-context`
  - `fail-closed-compact-property`
  - `fail-closed-reverse-literal`
  - `fail-closed-type-language-conflict`
  - `fail-closed-invalid-direction`
  - `fail-closed-typed-json-object-absolute-iri`
  - `fail-closed-non-string-index`
- Notes:
  - implemented-absolute-id-node: implemented; JS accepted=true; Swift accepted=true
  - implemented-nested-graph: implemented; JS accepted=true; Swift accepted=true
  - implemented-json-literal: implemented; JS accepted=true; Swift accepted=true
  - fail-closed-relative-id-node: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-blank-node-id: implemented; JS accepted=true; Swift accepted=true
  - fail-closed-nested-context: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-compact-property: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-reverse-literal: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-type-language-conflict: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-invalid-direction: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-typed-json-object-absolute-iri: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-non-string-index: bothReject; JS accepted=false; Swift accepted=false

### Canonicalization Engine Differential

- Result: PASS
- Compared cases: 5
- Duration: 2422 ms
- Case IDs:
  - `engine-vcb-document`
  - `engine-data-integrity-proof`
  - `engine-status-list-document`
  - `engine-status-list-proof`
  - `engine-rejects-compact-unknown-vcb-field`
- Notes:
  - engine-vcb-document: vcbDocument; N-Quads SHA-256 711f1a0061a7de2fc19fdd3b44020647a4e9c24b88cd3212d9701cd1bb4ffe3d
  - engine-data-integrity-proof: dataIntegrityProof; N-Quads SHA-256 317e2786b39b0a763c1a51aefa756edfc4571214e920654a8ad91dbe70392ac8
  - engine-status-list-document: statusListDocument; N-Quads SHA-256 229f31e2c5b5c0652b46cad3a676ce8e65db9afc4867ff54cf70f464601cf2be
  - engine-status-list-proof: dataIntegrityProof; N-Quads SHA-256 ea8bbe8b6f2ce2862763ce62cce15d131e6d1fc5c233a370fa51b516d5492e29
  - engine-rejects-compact-unknown-vcb-field: vcbDocument; JS accepted=false; Swift accepted=false

### W3C RDFC-1.0 Conformance Subset

- Result: PASS
- Compared cases: 1
- Duration: 3381 ms
- Case IDs:
  - `w3c-rdfc-subset`

### W3C RDFC-1.0 Issued-Identifier Map Subset

- Result: PASS
- Compared cases: 1
- Duration: 526 ms
- Case IDs:
  - `w3c-rdfc-issued-map-subset`

### W3C RDFC-1.0 Negative Clique Fail-Closed Coverage

- Result: PASS
- Compared cases: 1
- Duration: 769 ms
- Case IDs:
  - `w3c-rdfc-negative-clique`

## Remaining Scope

- This report covers the selected official SDK baseline fixtures, generated non-PII fixtures, supported status-list parity fixtures, generic extension parity fixtures, JSON-LD behavior characterization cases, and the current W3C RDFC subset tests.
- It is not yet a final proof that handwritten canonical N-Quads have been removed from public verification.
- Final completion still requires the standards-grade or native-library-backed canonicalization engine described in `Docs/LONG_TERM_JS_PARITY_PLAN.md`.

