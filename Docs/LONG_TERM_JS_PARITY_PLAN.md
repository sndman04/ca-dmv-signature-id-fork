# Long-Term JavaScript Parity Plan

## Purpose

This document defines the long-term path for making the Swift verifier a fully implemented replacement for the official California DMV JavaScript verifier while removing brittle handwritten canonicalization logic.

The target is one-to-one behavioral and cryptographic parity with the official JavaScript SDK for every California DMV DL/ID verification behavior the JavaScript SDK covers. For JS-covered cases, Swift must not intentionally deviate in accepted inputs, rejected inputs, verification outcomes, canonicalization inputs, status behavior, or expiration behavior.

- Same verified, failed, revoked, expired, not-present, and unavailable outcomes.
- Same fail-closed behavior for unsupported data.
- Same parsed VCB credential semantics.
- Same AAMVA protected-component selection and optical hashes.
- Same cryptographic verification inputs for `ecdsa-xi-2023` and status-list proof verification.
- Same DMV production and UAT environment policy, except where this project intentionally documents a safer stricter policy.
- No JavaScript runtime dependency in the final default verifier.

Any behavioral deviation from JS-covered behavior is a security exception, not normal implementation discretion. It must be documented with:

- the exact JS behavior,
- the Swift behavior,
- the security reason for diverging,
- affected fixtures or inputs,
- user-visible result impact,
- owner approval.

The immediate driver for this plan is a production credential pair where the official JavaScript SDK verifies both PDF417 payloads, while the Swift verifier accepts one and rejects the other with `signatureMismatch`. Inspection showed the Swift AAMVA optical hash matched the JavaScript SDK, so the likely defect is in the Swift Data Integrity canonicalization/signature-input path, not in barcode parsing.

## Guiding Decision

Do not keep expanding handwritten N-Quads as the production verification strategy.

The current Swift verifier manually constructs canonical N-Quads for narrow DMV credential shapes. That approach is useful as a scaffold and for tests, but it is not safe as the long-term verifier because RDF Dataset Canonicalization blank-node labels are content-dependent. A credential can have the same high-level shape as a previously working credential and still canonicalize differently.

Long-term correctness requires one of these native-default strategies:

- A standards-grade Swift JSON-LD expansion plus RDF Dataset Canonicalization implementation.
- A small audited native bridge to a standards-grade canonicalization library.

A controlled compatibility bridge to the official JavaScript SDK is allowed only as a temporary oracle or fallback while the native implementation reaches parity. It is not the final product.

## Final Product Definition

The final product is a Swift Package that can replace the official JavaScript SDK for supported California DMV DL/ID verification use cases.

Required final deliverables:

- One-to-one replacement behavior for every DMV DL/ID verifier case covered by the selected official JS SDK baseline.
- Public Swift API remains privacy-minimized and source-compatible unless a breaking change is explicitly approved.
- Native-default verification of production and UAT VCB credentials.
- Native-default CBOR-LD decoding for the DMV registry entries used by supported credentials.
- Native-default JSON-LD/RDF canonicalization for Data Integrity proof verification.
- Native-default `ecdsa-xi-2023` VCB proof verification.
- Native-default `ecdsa-rdfc-2019` status-list proof verification, or whatever cryptosuite the official SDK supports for current DMV status lists.
- Native-default DID Web resolution with DMV host allowlists.
- Native-default Bitstring/Terse Bitstring status-list fetching and bit evaluation.
- Reference-JS oracle retained for development and CI parity only.
- No handwritten canonical N-Quads in the default verification path.
- No Node, JavaScriptCore, or JS SDK dependency required by the default verifier at runtime.
- Complete parity test suite covering positive, negative, malformed, network, status, and expiration cases.
- Published conformance report showing the Swift verifier's supported-scope parity against the selected official SDK baseline.

## Non-Goals

- Do not build a general identity-document data extraction API.
- Do not become a general-purpose VC/Data Integrity wallet SDK beyond the DMV DL/ID profiles required for parity.
- Do not expose parsed PII in public verification results.
- Do not commit real scans, real barcode payloads, photos, or decoded real identity data.
- Do not treat new handcrafted N-Quads special cases as a sufficient fix.
- Do not return `.verified` when any required verification stage is unsupported or unavailable.

## Target Architecture

The long-term architecture should separate orchestration from canonicalization and signature verification:

```text
CADMVVerifier public API
  -> AAMVA parse and CA DMV applicability checks
  -> VCB decode and credential profile validation
  -> AAMVA protected-component selection and optical hash
  -> DID Web resolution and verification method validation
  -> Data Integrity verification engine
       -> JSON-LD processing
       -> RDF Dataset Canonicalization
       -> ecdsa-xi-2023 verify-data construction
       -> P-256 signature verification
  -> Optional status-list verification engine
       -> status-list fetch policy
       -> ecdsa-rdfc-2019 verification
       -> bitstring status evaluation
  -> privacy-minimized result mapping
```

The Data Integrity engine should be swappable behind an internal protocol so the package can run:

- `referenceJS`: official SDK-backed oracle for development, CI parity, and optional temporary production bridge if approved.
- `nativeSwift`: standards-grade native implementation.
- `legacyHandbuilt`: current implementation retained only for regression comparison until removed.

The default engine in the completed product must be `nativeSwift` or a native-library-backed equivalent. `referenceJS` must not be required for normal package consumers.

## Parity Surface

Parity is not limited to final boolean validity. The Swift implementation must match the JavaScript SDK at each observable verification stage where a privacy-safe comparison is possible:

- AAMVA applicability:
  - issuer identification number
  - DL/ID subfile selection
  - issuing jurisdiction
  - issue-date requirement cutoff
- VCB discovery:
  - VCB subfile and field selection
  - required vs optional VCB policy
  - base64 tolerance and rejection behavior
- CBOR-LD:
  - registry entry handling
  - context/type/url expansion
  - deterministic credential model construction
  - duplicate-key and malformed-data rejection
- Credential validation:
  - context and type requirements
  - issuer and verification-method mode policy
  - proof type, cryptosuite, proof purpose, and proof value policy
  - credential status profile
- AAMVA protected data:
  - `protectedComponentIndex` decoding
  - protected field selection
  - canonical AAMVA byte generation
  - optical hash
- Data Integrity:
  - proof canonicalization
  - document canonicalization
  - verify-data byte construction
  - ECDSA signature acceptance/rejection
- DID Web:
  - allowed hosts
  - redirect policy
  - verification method lookup
  - key material decoding
- Status:
  - terse status-list URL calculation
  - status-list credential verification
  - bit index calculation
  - revoked/not-revoked/unavailable mapping
- Expiration:
  - credential `validUntil`
  - proof `expires`
  - malformed date behavior
- Public result mapping:
  - status
  - privacy-safe failure reason
  - unavailable vs failed distinctions

Where the Swift public API cannot expose the JS SDK's exact error object shape, the internal parity harness must still classify the same first failure stage and map it to the closest privacy-safe public result. That mapping must be documented and tested.

## Phase 0: Freeze And Characterize Current Behavior

Goal: preserve current behavior as a baseline without pretending it is complete.

Tasks:

- Add an internal verification-engine boundary around the current `ecdsa-xi-2023` and status-list proof paths.
- Rename or annotate the current handwritten canonicalization implementation as a legacy profile implementation.
- Add a known-limitation note to docs: handwritten N-Quads are not the long-term canonicalization path.
- Add privacy-safe regression records for the observed production mismatch:
  - No raw PDF417.
  - No decoded AAMVA fields.
  - No proof value.
  - Record only reference outcome, Swift outcome, VCB byte count, credential shape booleans, environment, optical hash, and verification method key id class if needed.
- Ensure current tests still pass.
- Add a parity dashboard format that can list:
  - fixture id
  - JS outcome
  - Swift outcome
  - matching stage
  - first divergence stage
  - whether divergence is accepted or blocking

Exit criteria:

- [x] Current verifier behavior is unchanged by design; the existing implementation is now routed through a legacy engine boundary.
- [x] The mismatch is tracked as a known parity failure in `Docs/PARITY_STATUS.md`.
- [x] CI can report parity failures separately from unit-test failures via `Tools/parity-status.sh`.
- [x] The legacy path is clearly labeled as incomplete and is not expanded except for instrumentation needed to replace it.

## Phase 1: Build The JavaScript Reference Oracle Harness

Goal: make the official JavaScript SDK the authoritative parity oracle in automated tests.

Tasks:

- Create a local command-line reference runner that accepts raw PDF417 from stdin and emits privacy-minimized JSON:
  - `valid`
  - high-level error category
  - issuer accepted
  - VCB required
  - VCB present
  - decoded VCB byte count
  - credential profile class
  - AAMVA optical hash
  - status-check outcome when enabled
- Keep the raw payload entirely in process memory.
- Do not write raw payloads to repo files, snapshots, logs, or test artifacts.
- Add test helpers that compare Swift results against reference JSON.
- Add stage-specific oracle modes when safe:
  - parse/applicability summary
  - VCB decode summary
  - optical hash
  - verify-data hash or full verify-data for synthetic fixtures
  - status URL and bit index
- Make the reference runner version explicit:
  - upstream SDK commit
  - dependency lock hash
  - local harness patches, if any
- Add a policy that reference-runner output must remain privacy-minimized by default.

Exit criteria:

- [x] `Tools/reference-runner.mjs` or a successor can run arbitrary stdin payloads.
- [x] CI can run reference parity checks when Node dependencies are available.
- [x] Missing Node/reference dependencies produce a clear skipped-parity result, not a false pass.
- [x] The oracle can identify the first divergence stage for supported test vectors.

## Phase 2: Fixture And Corpus Strategy

Goal: cover edge cases without leaking real identity data.

Fixture classes:

- Official DMV/UAT samples where redistribution is allowed.
- Synthetic AAMVA barcodes generated in tests.
- Synthetic CBOR-LD credentials generated from deterministic test keys.
- Redacted parity vectors derived from real observations:
  - raw payload excluded
  - PII excluded
  - cryptographic hashes allowed only when they cannot reconstruct PII and are needed for parity debugging
- Live-reference smoke tests that require explicit local opt-in and never run in normal CI with real payloads.

Fixture metadata requirements:

- Stable fixture id.
- Fixture class: official, synthetic, redacted-vector, local-only.
- Allowed storage level: committed, encrypted local-only, or prohibited.
- Whether JS parity is required.
- Whether native Swift parity is required.
- Expected public result.
- Expected first failure stage for negative fixtures.
- Notes for any intentional divergence.
- Security-exception id for any fixture where Swift intentionally differs from JS.

Required corpus coverage:

- Valid production credential shape.
- Valid UAT credential shape.
- Signature mismatch from tampered protected AAMVA field.
- Signature mismatch from tampered proof value.
- Missing VCB before requirement date.
- Missing VCB after requirement date.
- `requireVCB: true` before requirement date.
- Non-California issuer.
- California issuer with non-CA `DAJ`.
- DL and ID primary subfiles.
- Multiple subfiles with valid descriptor offsets.
- Malformed subfile descriptors.
- Unknown subfile designators.
- Escaped scanner control characters.
- Raw control characters.
- Segment terminator variants supported by AAMVA parsing.
- Empty payload.
- Payload missing `ANSI`.
- Truncated header.
- Truncated descriptors.
- Invalid issue dates.
- Boundary issue dates:
  - `09/28/2025`
  - `09/29/2025`
  - leap-year dates
  - impossible dates
- Malformed base64 VCB.
- Base64 with scanner whitespace.
- CBOR-LD valid minimal DMV credential.
- Unsupported CBOR-LD registry entries.
- Unknown CBOR-LD values characterized against the official SDK:
  - text-encoded unknown signed credential/proof fields that JS preserves;
  - unknown compressed numeric term ids that JS rejects.
- Duplicate CBOR map keys.
- Oversized CBOR map/array declarations.
- Deeply nested CBOR.
- Unsupported credential contexts.
- Unsupported credential types.
- Unsupported proof types.
- Unsupported cryptosuites.
- Unsupported proof purposes.
- UAT credential checked in production mode.
- Production credential checked in UAT mode.
- DID resolution timeout.
- DID document missing verification method.
- DID document key type mismatch.
- DID document host redirect.
- DID document malformed JSON.
- DID document with wrong controller/id relationships.
- DID document with multiple verification methods.
- DID document with valid method using unsupported key type.
- Status checking disabled.
- Status checking enabled and not revoked.
- Status checking enabled and revoked.
- Status checking enabled and unavailable.
- Status-list credential proof invalid.
- Status-list profile has unknown signed fields.
- Status-list bit index at byte and bit boundaries:
  - 0
  - 7
  - 8
  - 63
  - 64
  - last bit in a list
  - out of range
- Credential expiration:
  - before expiration
  - exactly at expiration
  - after expiration
  - malformed expiration date
  - proof expiration and credential `validUntil`

Exit criteria:

- [x] Every edge-case category has either a committed fixture, generated fixture, or documented reason it cannot be safely represented.
- [x] Parity tests compare Swift to the JavaScript oracle for committed official fixtures where the JavaScript SDK can run.
- [x] Privacy review confirms no real PII fixtures are committed.
- [x] Synthetic fixtures can be regenerated deterministically from source code and deterministic keys.
- [x] Every intentional JS/Swift behavior difference is tied to an approved security exception or recorded as a blocking parity gap.

## Phase 3: Complete Native CBOR-LD And Credential Model Parity

Goal: ensure the Swift verifier decodes DMV VCB bytes into the same credential semantics as the JavaScript SDK before replacing canonicalization.

Tasks:

- Audit the DMV CBOR-LD registry table against the official SDK:
  - context table
  - cryptosuite table
  - URL table
  - type table
  - numeric compact keys
- Add tests for every supported registry value.
- Add rejection tests for unsupported registry values.
- Confirm map key handling matches security policy:
  - duplicate keys rejected
  - unsupported signed credential fields fail closed unless the standards engine will include them in canonicalization
  - unsafe strings rejected where applicable
- Confirm decoded Swift credential models preserve all fields that affect signatures.
- Add oracle comparisons for decoded credential shape without exposing PII.
- Preserve JS-accepted text-encoded unknown signed fields for standards-grade canonicalization rather than dropping them; continue rejecting unknown compressed numeric term ids to match JS decode behavior.

Exit criteria:

- [x] Swift CBOR-LD decoding matches the official SDK for every committed fixture.
- [x] No signature-relevant field is dropped before canonicalization for supported fields; unknown signed fields fail closed until standards canonicalization can preserve them.
- [x] Unsupported credential shapes fail at a documented stage.

## Phase 4: Introduce A Standards-Grade Canonicalization Engine

Goal: replace handcrafted VC proof canonicalization with real JSON-LD/RDF canonicalization.

Evaluation requirements:

- Supports JSON-LD 1.1 expansion and RDF transformation needed by the DMV credential contexts.
- Supports RDF Dataset Canonicalization compatible with the official SDK behavior.
- Handles blank-node canonical labeling without hardcoded assumptions.
- Has a license compatible with this package.
- Has a small auditable surface.
- Can be sandboxed or isolated if implemented outside Swift.
- Can run on the package's target platforms or is cleanly optional per platform.
- Does not require Node or the official JS SDK in the final default verifier.

Candidate implementation paths:

- Native Swift implementation of the needed JSON-LD and RDF canonicalization algorithms.
- Swift wrapper around a C or Rust canonicalization library with a narrow C ABI.
- Temporary Node/JavaScript bridge to the official SDK for development parity only.

Current engine decision:

- See `Docs/CANONICALIZATION_ENGINE_DECISION.md`.
- The default verifier remains native Swift with no runtime bridge while Phase 4 hardening continues.
- External canonicalization dependencies must satisfy the documented parity, license, memory-safety, build, and platform criteria before adoption.

Native implementation milestones:

- JSON-LD context loading policy:
  - use pinned contexts for known DMV/VC/security contexts
  - no arbitrary network context loading during verification
  - fail closed on unsupported contexts
- RDF conversion:
  - reproduce reference RDF dataset for official fixtures
  - preserve datatypes and IRIs exactly
  - support credential subject and status-list blank nodes
  - include unknown supported-by-standard signed fields instead of silently dropping them
- Canonicalization:
  - implement or bind URDNA2015/RDFC behavior used by the SDK
  - verify blank-node labels are derived, not guessed
  - compare canonical N-Quads against reference output in tests
- Verify-data construction:
  - proof hash
  - document hash
  - external optical-data hash
  - byte concatenation order matching `ecdsa-xi-2023`

Progress:

- The VCB document graph now uses derived blank-node labels for the supported DMV credential graph instead of hardcoded `_:c14n` assumptions.
- Supported VCB document JSON-LD-to-RDF expansion is isolated in `VCBJSONLDRDFExpander`; the verifier now consumes canonical N-Quads from that boundary instead of assembling the document graph inline.
- VCB proof, status-list proof, and status-list document canonicalization now use structured RDF terms and a shared N-Quads renderer rather than independent raw string emitters.
- Blank-node canonicalization now includes the RDFC n-degree path for shared first-degree hashes, covered by the W3C shared-hash example, with a bounded recursion budget for fail-closed behavior on overly complex graphs.
- The RDF dataset model now supports named graphs and blank nodes in graph names, so canonicalization operates on quads rather than only default-graph triples.
- The JS oracle and parity comparator now compare VCB verify-data for committed official UAT fixtures, including the invalid-signature fixture.
- The JS oracle smoke gate now also compares synthetic `ecdsa-rdfc-2019` status-list verify-data against Swift for the base status list and optional live-style VC fields.
- The generated VCB signature parity gate now signs and encodes synthetic credentials with status, validity dates, and combined status plus validity dates, then compares JS and Swift canonical N-Quads, verify-data, byte length, optical hash, and verification result.
- The observed production mismatch class, where two otherwise valid credentials canonicalized with different subject/status blank-node ordering, is covered by synthetic tests and rechecked locally without storing raw payloads or PII.
- VCB document canonicalization now goes through `SupportedJSONLDRDFConverter`, a supported-context JSON-LD-to-RDF boundary that consumes a JSON-LD projection and fails closed for unsupported contexts or unknown signed terms instead of silently dropping them.
- Canonicalization engine selection is documented in `Docs/CANONICALIZATION_ENGINE_DECISION.md`: continue native Swift hardening now, use JS only as a development oracle, and require explicit bridge/dependency acceptance criteria before adding an external engine.
- This is an intermediate milestone. The current implementation is a fail-closed DMV profile graph builder plus RDF term renderer, not a complete JSON-LD/RDF Dataset Canonicalization replacement.
- Remaining Phase 4 work includes profile-independent JSON-LD/RDF processing, reference-equivalent comparisons for any remaining synthetic fixture classes, and the final standards-grade/native-library-backed engine decision.

Exit criteria:

- Native or native-library-backed canonicalization produces reference-equivalent verify-data for all committed official and synthetic fixtures.
- The observed production mismatch class is resolved by the new engine.
- Handbuilt N-Quads are no longer used by the default verifier.
- Any native-library bridge has documented memory-safety, license, build, and platform implications.

## Phase 5: Replace `ecdsa-xi-2023` Verification

Goal: make VCB signature verification match the official SDK for production and UAT credentials.

Tasks:

- Route VCB proof verification through the new Data Integrity engine.
- Keep P-256 signature verification in Swift Crypto where possible.
- Confirm proof value decoding:
  - multibase `z`
  - base58btc
  - 64-byte raw `r || s`
  - reject malformed lengths
- Confirm signature policy matches reference SDK:
  - valid high-S and low-S signatures accepted or rejected consistently with reference behavior
  - invalid DER/raw encodings rejected
- Validate verification method binding:
  - proof verification method exactly matches resolved DID key id
  - expected mode host enforced
  - unsupported key material fails closed

Exit criteria:

- Swift result equals JavaScript result for all VCB signature fixtures.
- AAMVA optical hash parity and verify-data parity are both tested.
- `signatureMismatch` is reserved for genuine proof verification failure, not canonicalization drift.
- The default VCB signature path has no JS runtime dependency.

Progress:

- `Tools/signature-policy-characterization.mjs` records reference Data Integrity behavior for `z` base58btc and `u` base64url proof values, unsupported prefixes, malformed base58btc values, permissive short/malformed `u` handling before the real signature verifier, and P-256 high-S counterpart verification through WebCrypto.
- Swift proof parsing now preserves reference-supported text `z` and `u` proofValue encodings for the verifier, rejects malformed or non-64-byte raw signatures before Swift Crypto verification, and accepts the high-S/low-S counterpart pair consistently with WebCrypto.
- `Tools/generated-signature-parity.mjs` now generates runtime synthetic VCB signatures and injected DID documents, then compares JS and Swift end-to-end barcode verification for valid `z`, valid `u`, status-bearing credentials, validity-date credentials, combined status plus validity-date credentials, tampered proof signature, and tampered protected AAMVA field cases.
- Swift CBOR-LD decode now accepts the reference-emitted compressed proof key layout for no-status credentials and numeric epoch-second proof date values.

## Phase 6: Replace Status-List Proof Canonicalization

Goal: remove handwritten status-list N-Quads and verify status credentials through the same standards-grade path.

Tasks:

- Model status-list credentials as JSON-LD inputs to the canonicalization engine.
- Verify `ecdsa-rdfc-2019` status-list proofs with reference-compatible canonicalization.
- Preserve current network policy:
  - DMV status host allowlist
  - no unsafe redirects
  - bounded timeouts
  - explicit `.unavailable` on network or unsupported profile failure
- Keep bitstring decompression protections:
  - max output size
  - malformed gzip rejection
  - out-of-range index rejection
- Add profile drift tests:
  - new signed root fields
  - new credential subject fields
  - new proof fields
  - optional standard fields observed in production

Exit criteria:

- Status-list proof verification matches JavaScript reference behavior for synthetic and live-compatible fixtures.
- Unknown signed status-list fields no longer require hand-editing N-Quads; they are handled by canonicalization or fail closed due to explicit policy.
- Required status checks never downgrade to `.verified` when the status-list fetch, parse, proof, or bit check is unavailable.

## Phase 7: End-To-End Result Mapping And API Compatibility

Goal: ensure the fully native verifier remains a drop-in Swift package with privacy-safe public behavior.

Tasks:

- Compare public result mapping against the JS SDK for every parity fixture.
- Confirm failure reasons remain privacy-safe:
  - no raw barcode
  - no parsed AAMVA PII
  - no decoded credential
  - no proof value
  - no DID document
  - no status-list content
- Confirm async/network behavior:
  - bounded timeouts
  - cancellation propagation
  - no global mutable network state in production
  - deterministic injectable network client for tests
- Confirm platform behavior:
  - iOS supported target compiles
  - macOS supported target compiles
  - scanner target remains optional
  - core verifier has no UIKit/SwiftUI dependency
- Confirm documentation covers integration policy:
  - only `.verified` means verified
  - `.unavailable` is distinct from `.failed`
  - status-check disabled vs enabled behavior
  - privacy-safe telemetry

Exit criteria:

- Native implementation is API-compatible with existing package consumers or breaking changes are explicitly documented.
- Public behavior matches the reference oracle for supported cases.
- Documentation matches implementation behavior.

## Phase 8: Differential And Fuzz Testing

Goal: prevent regressions and find parser/canonicalization disagreements.

Test layers:

- Unit tests for each component.
- Golden vector tests against the JavaScript oracle.
- Differential tests:
  - generate synthetic AAMVA/VCB pairs
  - run Swift and JS
  - compare outcomes and privacy-safe diagnostics
- Mutation tests:
  - flip protected AAMVA bytes
  - flip unprotected AAMVA bytes
  - mutate VCB base64
  - mutate CBOR map keys
  - mutate proof metadata
  - mutate status-list indexes
- Parser fuzzing:
  - AAMVA headers
  - descriptors
  - subfile boundaries
  - control separators
  - CBOR-LD byte streams
- Network simulation tests:
  - timeout
  - DNS failure
  - redirect
  - 404
  - 500
  - malformed DID document
  - unsupported key
  - malformed status-list credential

CI gates:

- Fast unit tests on every push.
- Reference parity tests on every push when Node is available.
- Extended differential corpus nightly or manually.
- Fuzz tests scheduled or manually triggered with persisted crash seeds.
- Security-exception inventory check: any JS/Swift mismatch must either fail CI or reference an approved exception.

Exit criteria:

- No known Swift/JS parity mismatches for supported fixtures.
- Any accepted divergence has a documented security rationale.
- Fuzz-found crashes become regression fixtures.
- Differential test failures block release unless explicitly classified as accepted divergence.
- Accepted divergences are limited to approved security exceptions.

## Phase 9: Production Readiness And Removal Of Legacy Path

Goal: ship a fully implemented Swift replacement whose correctness does not depend on hardcoded N-Quads or the JavaScript SDK at runtime.

Tasks:

- Make the standards-grade engine the only default verification path.
- Remove or quarantine legacy handbuilt N-Quads behind test-only SPI.
- Remove any production runtime dependency on Node, JavaScriptCore, or the official JS SDK.
- Update public docs to remove "limited profile" caveats that no longer apply, or narrow them to intentional policy limits.
- Publish integration guidance:
  - handling `.verified`
  - handling `.failed`
  - handling `.unavailable`
  - status-check policy
  - privacy-safe telemetry
- Complete dependency/license review for the canonicalization engine.
- Complete threat-model update for any bridge or native dependency.
- Add release checklist:
  - all parity gates pass
  - all fuzz crash seeds pass
  - dependency audit complete
  - privacy review complete
  - docs updated
  - conformance report generated
  - known divergences listed and approved
  - security-exception inventory reviewed

Exit criteria:

- Default verifier passes all parity gates.
- Legacy handbuilt canonicalization is not reachable from public verification.
- Documentation describes the new engine and its security boundary accurately.
- JS SDK is retained only as a test oracle and upstream behavior reference.
- Package consumers can verify supported DMV DL/ID VCBs without installing JavaScript tooling.
- A conformance report records the official SDK baseline version, supported cases, skipped cases, and any approved divergences.
- Any approved divergence is clearly identified as a security exception, not a parity gap.

## Acceptance Criteria

The long-term project is complete only when all of these are true:

- Swift is a one-to-one replacement for every DMV DL/ID verification behavior covered by the selected official JavaScript SDK baseline.
- Every supported official JavaScript SDK fixture has the same result in Swift.
- Every committed synthetic fixture has matching Swift and JavaScript results where the JavaScript SDK supports the case.
- Every supported verification stage has parity coverage, not just final valid/invalid output.
- The observed production mismatch class is fixed by standards-grade canonicalization, not by a one-off special case.
- No raw real barcode payloads or parsed PII are committed.
- Public API results remain privacy-minimized.
- Unsupported credential shapes fail closed.
- Required status-check infrastructure failures return `.unavailable`, not `.verified`.
- The verifier can explain failure classes without exposing sensitive data.
- The default verifier has no Node, JavaScriptCore, or official JS SDK runtime dependency.
- Handwritten canonical N-Quads are not reachable from the public verification path.
- Dependency, license, threat-model, and integration docs are updated for the final architecture.
- A conformance report exists and can be regenerated from committed non-PII fixtures plus documented local-only optional inputs.
- Any behavior that differs from the selected JS baseline has an approved security-exception record.

## Immediate Next Build Tasks

1. Add an internal `DataIntegrityVerificationEngine` boundary.
2. Add a JS reference runner that accepts stdin payloads and emits privacy-minimized JSON.
3. Add parity test scaffolding that can run Swift and JS side by side.
4. Add a redacted regression record for the current production parity mismatch.
5. Research canonicalization implementation options and document license/platform tradeoffs.
6. Audit CBOR-LD registry/model parity against the official SDK.
7. Choose the temporary bridge strategy for development and CI only:
   - reference JS engine for correctness oracle now, or
   - continue defaulting to Swift with a documented known parity risk.
8. Begin replacing handcrafted VCB canonicalization before expanding feature coverage.
9. Define release gates that require no JS runtime dependency in the final default verifier.
10. Add a security-exception record format for any intentional deviation from JS-covered behavior.

## Open Questions

- Which platforms must support the fully native canonicalization engine at launch?
- Is a JavaScript bridge acceptable as a temporary production verifier during migration, or only as a CI oracle?
- Should the package expose a verifier-engine selection option, or keep that internal?
- What is the policy for local opt-in testing with real scans that cannot be committed?
- Which canonicalization implementation path has the best license, maintenance, and platform profile?
- Should unknown standards-valid signed fields be preserved generically through canonicalization, or should the verifier continue to fail closed unless each field is explicitly policy-approved?
- What exact upstream SDK version becomes the first long-term parity baseline?
- Who approves security exceptions when Swift behavior intentionally differs from the JS SDK?
