# Conformance Report

Generated: 2026-07-04T02:27:23.088Z
Repository revision: `d23d6cd`
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
| W3C RDFC-1.0 Conformance Subset | `Tools/swift-test.sh --filter RDFDatasetCanonicalizerTests/testW3CRDFC10ConformanceSubset` | 1 | PASS |
| W3C RDFC-1.0 Issued-Identifier Map Subset | `Tools/swift-test.sh --filter RDFDatasetCanonicalizerTests/testW3CRDFC10IssuedIdentifierMapSubset` | 1 | PASS |
| W3C RDFC-1.0 Negative Clique Fail-Closed Coverage | `Tools/swift-test.sh --filter RDFDatasetCanonicalizerTests/testW3CRDFC10NegativeCliqueGraphFailsClosed` | 1 | PASS |

## Covered Cases

### Official UAT Fixture Parity

- Result: PASS
- Compared cases: 2
- Duration: 1762 ms
- Case IDs:
  - `official-valid-uat`
  - `official-invalid-uat`

### Generated Signature Parity

- Result: PASS
- Compared cases: 8
- Duration: 6206 ms
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
- Duration: 5117 ms
- Case IDs:
  - `synthetic-status-list-base`
  - `synthetic-status-list-optional-fields`
  - `synthetic-status-list-absolute-iri-extensions`
- Notes:
  - synthetic-status-list-base: document N-Quads SHA-256 32f9e3eb0ef441494d9f35b40deed3703c7730e491db83245714e0a1475100c1; proof N-Quads SHA-256 93fa093cba64513885ce626317a174530e4d19527212094b1571d4b8e665a221
  - synthetic-status-list-optional-fields: document N-Quads SHA-256 754ba90533e8d44df66599957c68a3f9f2cccac0f1380c538f17926967783567; proof N-Quads SHA-256 93fa093cba64513885ce626317a174530e4d19527212094b1571d4b8e665a221
  - synthetic-status-list-absolute-iri-extensions: document N-Quads SHA-256 5145fc63727d9664674b26da904f2f9bfc26b9a3447093daca3d68075cb0dba0; proof N-Quads SHA-256 25531b3b22dbaac7f78a3da77fdabc29e78bd37ac6ff84ff3c263f42aaf50abc

### Generic VCB JSON-LD Extension N-Quads Parity

- Result: PASS
- Compared cases: 1
- Duration: 551 ms
- Case IDs:
  - `generic-jsonld-extension-values`

### Generic Proof JSON-LD Extension N-Quads Parity

- Result: PASS
- Compared cases: 1
- Duration: 542 ms
- Case IDs:
  - `generic-proof-extension-values`

### JSON-LD 1.1 Behavior Characterization

- Result: PASS
- Compared cases: 12
- Duration: 6200 ms
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
  - fail-closed-blank-node-id: swiftFailClosed; JS accepted=true; Swift accepted=false
  - fail-closed-nested-context: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-compact-property: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-reverse-literal: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-type-language-conflict: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-invalid-direction: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-typed-json-object-absolute-iri: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-non-string-index: bothReject; JS accepted=false; Swift accepted=false

### W3C RDFC-1.0 Conformance Subset

- Result: PASS
- Compared cases: 1
- Duration: 4452 ms
- Case IDs:
  - `w3c-rdfc-subset`

### W3C RDFC-1.0 Issued-Identifier Map Subset

- Result: PASS
- Compared cases: 1
- Duration: 518 ms
- Case IDs:
  - `w3c-rdfc-issued-map-subset`

### W3C RDFC-1.0 Negative Clique Fail-Closed Coverage

- Result: PASS
- Compared cases: 1
- Duration: 760 ms
- Case IDs:
  - `w3c-rdfc-negative-clique`

## Remaining Scope

- This report covers the selected official SDK baseline fixtures, generated non-PII fixtures, supported status-list parity fixtures, generic extension parity fixtures, JSON-LD behavior characterization cases, and the current W3C RDFC subset tests.
- It is not yet a final proof that handwritten canonical N-Quads have been removed from public verification.
- Final completion still requires the standards-grade or native-library-backed canonicalization engine described in `Docs/LONG_TERM_JS_PARITY_PLAN.md`.

