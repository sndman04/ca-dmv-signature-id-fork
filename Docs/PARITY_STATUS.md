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

Phase 5 is complete.

Completed:

- Long-term one-to-one JS parity plan created.
- Main planning document links to the long-term parity plan.
- Current supported-profile VCB and status-list proof verification paths are isolated behind `SupportedProfileDataIntegrityEngine`.
- Supported proof and document canonicalization paths pass through JSON-LD-to-RDF conversion boundaries, but remain replacement targets for the final standards-grade/native canonicalization engine.
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
- `Tools/parity-compare.mjs` compares Swift and JS summaries for committed official UAT fixtures, including VCB verify-data.

Completed Phase 1 gates:

- Commit and push completed Phase 1.

Completed Phase 2 work:

- Added `Tests/CADMVVerifierTests/Fixtures/fixture-manifest.json`.
- Added `Docs/FIXTURE_CORPUS.md`.
- Added manifest validation tests for required categories and privacy constraints.
- Materialized generated `ID` primary-subfile coverage for AAMVA parsing, applicability, VCB requirement handling, and protected-field selection.

Completed Phase 2 gates:

- Build and tests pass with no warnings.
- Phase 2 changes committed and pushed.

Completed Phase 3 work:

- Added `Docs/CBORLD_REGISTRY_AUDIT.md`.
- Expanded `Tools/parity-compare.mjs` to compare VCB byte length and privacy-safe credential profile fields.
- Added `Tools/cborld-unknown-field-characterization.mjs` to record reference JS behavior for text-encoded unknown signed fields and unknown compressed numeric term ids.

Completed Phase 3 gates:

- Build and parity checks pass with no warnings.
- Phase 3 changes committed and pushed.

Completed Phase 4 work:

- Replaced hardcoded VCB document blank-node label ordering with deterministic graph-derived labels for the supported DMV credential graph.
- Moved supported VCB document JSON-LD-to-RDF expansion into `VCBJSONLDRDFExpander`, keeping the verifier focused on proof/document/external hash composition and signature verification.
- Routed VCB proof, status-list proof, and status-list document canonicalization through structured RDF terms and the shared N-Quads renderer instead of raw string assembly.
- Added RDFC-style n-degree hashing for shared first-degree blank-node hashes, with an explicit recursion/work budget and negative coverage that fails closed when the budget is exceeded.
- Added RDF dataset graph-name support, including blank nodes used as graph names, so the canonicalizer handles quads rather than default-graph triples only.
- Added JS oracle VCB verify-data output and made `Tools/parity-compare.mjs` fail on official-fixture verify-data mismatches.
- Added JS/Swift VCB proof and document canonical N-Quads comparisons for committed official UAT fixtures.
- Added `Tools/status-list-parity.mjs` to compare JS and Swift `ecdsa-rdfc-2019` verify-data for synthetic status-list fixtures, including optional live-style VC fields and safe absolute-IRI extension terms on the status-list root, credentialSubject, and proof.
- Added synthetic regression coverage for the observed production class where status-list and subject blank nodes can swap canonical order based on credential content.
- Added exact-output proof canonicalization tests for optional `created` and `expires` handling, plus W3C shared-hash canonicalization coverage.
- Rechecked the prohibited-storage production vector locally in memory; the previous `data-integrity-vcb` divergence is resolved without committing raw payloads or PII.
- Characterized `unknown-ignorable-cborld-values`: JS preserves text-encoded unknown credential/proof fields but rejects unknown compressed numeric term ids; Swift preserves JS-accepted text-key unknown fields in decoded JSON-LD state, rejects unknown numeric term ids during decode, canonicalizes safe absolute-IRI extensions, and fails closed for compact unknown terms in parity with the JS safe-mode canonicalizer.
- Documented the canonicalization engine decision and external bridge acceptance criteria in `Docs/CANONICALIZATION_ENGINE_DECISION.md`.
- Added `SupportedJSONLDRDFConverter` so VCB document canonicalization now flows through a supported-context JSON-LD-to-RDF conversion boundary instead of directly assembling RDF quads from the credential model; unsupported contexts and unknown signed terms fail closed at that boundary.
- Expanded generated VCB signature parity to cover runtime-signed credentials with `credentialStatus`, `validFrom`/`validUntil`, combined status plus validity dates, and an expired valid signature, comparing JS and Swift canonical N-Quads, verify-data, AAMVA hash, byte length, failure stage, and final verification result.
- Added `StatusListJSONLDRDFExpander` and `SupportedStatusListJSONLDRDFConverter` so status-list document canonicalization also flows through a supported-context JSON-LD-to-RDF boundary; unsupported contexts, unknown signed terms, unknown type values, and unsafe date text fail closed there.
- Routed Data Integrity proof canonicalization through `SupportedProofJSONLDRDFConverter`, so VCB and status-list proof configs now build supported JSON-LD first and fail closed for unsupported contexts, unknown proof terms, unsupported cryptosuites, unsupported proof purposes, unknown proof types, and unsafe date text.
- Added `JSONLDCanonicalizationEngine` and the default `SupportedProfileJSONLDCanonicalizationEngine` so VCB document, status-list document, and proof canonicalization share one replaceable engine seam; focused tests assert each path routes through the configured profile.
- Centralized shared RDF primitive emission for supported JSON-LD converters, so VCB documents, status-list documents, and Data Integrity proofs use the same type, IRI, literal, and date-time quad construction while retaining profile-specific fail-closed errors.
- Added generic canonicalization for safe absolute-IRI JSON-LD extension terms in VCB documents, status-list documents, and Data Integrity proofs. Strings, JSON integers, JSON doubles, booleans, arrays, `@set` containers, `@list` containers, null omission, nested absolute-IRI objects, `@id` node references, node-object `@type`, node-object `@reverse`, node-object `@graph` named graphs, node-object `@included`, node-object `@nest`, string `@index` metadata, and `@value` objects with safe datatype `@type`, `@language`, `@direction`, or `@type: "@json"` metadata are now included in RDF output; compact unknown terms, unsafe IRIs, invalid direction values, non-string `@index` values, invalid non-JSON value-object shapes, and invalid nested node blocks still fail closed.
- Added `Tools/generic-jsonld-extension-parity.mjs` to compare JS and Swift canonical VCB document N-Quads for the generic extension subset, including `@id`, node-object `@type`, node-object `@reverse`, node-object `@graph`, node-object `@included`, node-object `@nest`, string `@index`, directed `@value`, `@json` value objects, `@set`, and `@list` values.
- Added `Tools/generic-proof-extension-parity.mjs` to compare JS and Swift canonical Data Integrity proof N-Quads for the same generic extension subset, including proof-local `@id`, node-object `@type`, node-object `@reverse`, node-object `@graph`, node-object `@included`, node-object `@nest`, string `@index`, directed `@value`, `@json` value objects, `@set`, and `@list` values.
- Extended `Tools/status-list-parity.mjs` to compare status-list document and proof canonical N-Quads directly, with SHA-256 fingerprints in the summary output in addition to final verify-data hex.
- Added `Tools/canonicalization-engine-differential.mjs` as the replacement-engine contract gate: VCB document, VCB proof, status-list document, status-list proof, and official valid/invalid UAT VCB document/proof canonicalization must match the JavaScript SDK byte-for-byte for accepted canonical N-Quads, and fail-closed cases must match JS accept/reject behavior.
- Added `Tools/generate-conformance-report.mjs` and `Docs/CONFORMANCE_REPORT.md` so the current privacy-safe parity corpus can be regenerated into a committed conformance summary.
- Added `Tools/jsonld-behavior-characterization.mjs` and `Docs/JSONLD_BEHAVIOR_CHARACTERIZATION.md` to classify representative JSON-LD edge shapes; explicit blank-node `@id` values with safe local labels are now implemented in the generic extension path and covered by VCB, proof, and status-list parity fixtures.
- Updated VCB profile validation to allow only extension fields that the generic absolute-IRI RDF path can canonicalize, making those supported extension terms reachable from the normal verifier while keeping compact unknown terms fail-closed.
- Added W3C RDFC-1.0 subset coverage for empty datasets, blank nodes, graph names, shared graph names, language/datatype literals, Unicode and control-character escaping, duplicate input quads, and the negative clique graph; the native canonicalizer now de-duplicates RDF datasets before canonical labeling/rendering.
- Added an internal RDFC issued-identifier map API and W3C map-test subset coverage, so canonical blank-node labeling can be asserted directly instead of only through rendered N-Quads.
- Added a pinned JSON-LD term registry for the DMV, VC, status-list, schema.org, and security terms currently accepted by VCB, status-list, and proof converters; converters now use that registry while continuing to fail closed for unsupported signed terms.
- Moved supported JSON-LD context-set policy for VCB documents, status-list documents, and proof documents into the pinned registry with profile-specific rejection coverage.
- Centralized JSON serialization input conversion in `SupportedJSONLDValue.fromJSON`, with unit coverage for bool, unsigned, negative, double, null, array, object, and profile-specific error mapping.
- Added decoded `additionalProperties` storage for JS-accepted text-key unknown VCB credential and proof fields, projected those fields into the internal JSON-LD documents, canonicalized safe absolute-IRI extensions, and kept compact unknown terms fail-closed in parity with reference safe-mode canonicalization.
- Added fail-closed decode coverage for compressed VCB maps that contain text aliases for known signed terms, preventing ambiguous duplicate values from overwriting the numeric compressed value during JSON-LD projection.
- Added `additionalProperties` storage for unknown status-list root, credentialSubject, and proof fields, projected those fields into status-list document/proof JSON-LD, and allow safe absolute-IRI extensions through the supported canonicalization path while keeping compact unknown fields and unsafe IRIs fail-closed as unavailable.

Completed Phase 5 work:

- Added `Tools/signature-policy-characterization.mjs` to record reference Data Integrity proofValue decoding, permissive short/malformed `u` handling before the real signature verifier, and WebCrypto high-S counterpart behavior.
- Matched JS proofValue multibase policy for text `z` base58btc and `u` base64url encodings while continuing to require exactly 64 raw P-256 signature bytes before Swift Crypto verification.
- Added Swift tests for proofValue prefix/length rejection and high-S counterpart acceptance through `ECDSAProofVerifier`.
- Added `Tools/generated-signature-parity.mjs` to create runtime synthetic VCB signatures with an injected DID document and compare JS/Swift valid `z`, valid `u`, status-bearing credentials, validity-date credentials, combined status plus validity-date credentials, expired valid-signature credentials, tampered proof signature, and tampered protected AAMVA field outcomes, first failure stages, AAMVA hashes, canonical N-Quads, verify-data, and VCB byte lengths.
- Added Swift decoder support for reference-emitted no-status compressed proof key ids and numeric epoch-second proof date values.

Remaining Phase 4 gates:

- Replace the remaining supported-context JSON-LD/RDF converter with the selected standards-grade or native-library-backed canonicalization engine.
- Add reference-equivalent canonical N-Quads or verify-data comparisons for any remaining synthetic fixture classes beyond the committed official UAT, generated VCB, and status-list parity cases.
- Apply the documented memory-safety, license, build, and platform criteria if a native-library bridge is selected later.

Completed Phase 5 gates:

- Generated end-to-end signature parity fixtures beyond the committed official UAT valid/invalid pair pass through the JS oracle smoke gate.
- `signatureMismatch` is covered by generated cases where JS and Swift agree on canonical N-Quads and verify-data and only the signature/protected AAMVA mutation causes `data-integrity-vcb` failure.
