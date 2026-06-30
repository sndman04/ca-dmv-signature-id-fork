# CA DMV Swift Verifier Planning Document

## Purpose

This document is the source of truth for planning, implementation tracking, security decisions, and open questions for the Swift-native fork of the California DMV DL/ID digital-signature verifier.

The baseline product requirements are defined in:

- `CA_DMV_DLID_SWIFT_VERIFIER_REQUIREMENTS.md`

When this plan conflicts with the requirements document, the requirements document controls unless this plan records an intentional decision and rationale. When either document conflicts with the California DMV technical guide or official JavaScript SDK behavior, follow DMV's published guide and official SDK behavior.

## Current Status

Project phase: implementation verification
Current implementation phase: bug/security/documentation review for the completed current-scope verifier

Implementation status:

- [x] Requirements document reviewed.
- [x] Planning document created.
- [x] Official JavaScript SDK cloned or vendored for reference.
- [x] DMV technical guide reviewed in detail.
- [x] Swift Package scaffolded.
- [x] Public API finalized.
- [x] Security model finalized.
- [x] Fixture policy finalized for committed fixtures.
- [x] First implementation milestone started.
- [x] Project owner decisions recorded for license compliance, platform breadth, scanner shape, debug policy, and implementer options.

Cryptographic verification is implemented for the DMV VCB profile covered by the official UAT samples. Status-list credential verification is implemented for the supported DMV VC v2 Bitstring Status List profile and covered by a synthetic JavaScript-reference vector. The official UAT sample still returns `unavailable` when status checking is required because the live UAT status endpoint does not currently provide a usable status-list credential.

## Guiding Priorities

1. Security and safety come first.
2. Privacy comes before developer convenience.
3. Verification must fail closed.
4. The package should be Swift-native wherever practical.
5. Any non-Swift fallback must be minimal, auditable, memory-safe where possible, and isolated behind a narrow Swift API.
6. Behavior should match the official DMV JavaScript SDK unless there is a documented reason to diverge.
7. Documentation must be good enough that an app developer can integrate the package without reading the internals.

## Target Platform

Language target:

- Swift 6.3
- Swift Package Manager

Core verifier platform target:

- All platforms that can compile the Swift package and its selected dependencies.
- Apple platforms should receive first-class support.
- iOS 26 should be the primary app-integration target.
- macOS should be supported for local tools, tests, CI, and app integrations.
- Non-Apple Swift platforms should remain supported by the core verifier whenever dependencies allow it.

Scanner platform target:

- iOS 26 first.
- Other platforms only where native camera/scanning APIs are practical and safe.

Package principles:

- No UIKit dependency.
- No SwiftUI dependency.
- No app storage dependency.
- No app logging dependency.
- No analytics, telemetry, or background persistence.
- Strict concurrency checking enabled where possible.
- `Sendable` public models.
- Async APIs for network-dependent verification.
- Core verifier accepts already scanned raw PDF417 data.
- Barcode scanning support is an explicit requirement, but should live in a separate optional target so camera/UI permissions do not become mandatory for server-side, macOS, or scanner-hardware integrations.
- Core verifier should avoid platform-specific frameworks unless they are conditionally compiled or isolated.

Input modes:

- Primary verification input: already scanned raw PDF417 barcode data.
- Optional capture input: native scanner UI that captures PDF417 data and immediately hands the raw payload to the core verifier.
- Integrations using external hardware scanners, backend services, MDM apps, or existing scan flows should use the raw input API and should not depend on `CADMVScanner`.

## Security Model

This project handles raw PDF417 barcode data from government identity documents. Raw barcode data can contain personally identifiable information and must be treated as sensitive.

Security rules:

- Do not log raw PDF417 data.
- Do not log parsed AAMVA fields.
- Do not log decoded credentials by default.
- Do not persist raw barcode data.
- Do not persist parsed PII.
- Do not expose PII in public result objects.
- Do not include PII in thrown errors, result messages, debug descriptions, test names, or snapshots.
- Use redacted internal errors for diagnostics.
- Make any debug mode explicitly opt-in and clearly unsafe for production logging.
- Keep network access restricted to DMV-controlled allowlisted hosts for the selected mode.
- Reject unsupported algorithms, contexts, cryptosuites, issuers, verification methods, status-list types, and registry entries.
- Return `unavailable` instead of `verified` when required online status checks cannot complete.
- Treat unexpected or partially decoded data as verification failure.
- Prefer immutable value types.
- Avoid global mutable state.
- Use constant-time comparison for sensitive byte equality where applicable.

## Non-Swift Fallback Policy

The goal is to implement the verifier in Swift as completely as possible.

Allowed fallback hierarchy:

1. Swift standard library, Foundation, Apple CryptoKit-compatible APIs through `swift-crypto`, Security framework, and URLSession.
2. Small, well-maintained Swift packages with clear licenses and narrow responsibilities.
3. C libraries only when there is no safe Swift option, and only behind a carefully audited Swift wrapper.
4. C++ only if unavoidable and isolated behind a C-compatible boundary.
5. JavaScript runtimes are not acceptable for the core verifier unless explicitly approved later as a temporary compatibility bridge.

Fallback requirements:

- Document why the fallback is required.
- Document license compatibility.
- Document memory-safety risks.
- Keep the boundary small and testable.
- Add fuzz or malformed-input tests around the boundary when practical.
- Never pass raw PII into a fallback dependency unless it is strictly required for verification.

Likely areas requiring special review:

- CBOR-LD decoding.
- RDF Dataset Canonicalization / Data Integrity behavior.
- `ecdsa-xi-2023` cryptosuite verification.
- `ecdsa-rdfc-2019` verification for status-list credentials.
- Bitstring Status List processing.

## Public API Direction

The intended public surface should stay small and privacy-minimized:

```swift
public enum CADMVVerificationStatus: Equatable, Sendable {
    case verified
    case failed
    case notPresent
    case revoked
    case expired
    case unavailable
}

public struct CADMVVerificationResult: Equatable, Sendable {
    public let status: CADMVVerificationStatus
    public let message: String?
}

public struct CADMVVerificationOptions: Sendable {
    public var requireVCB: Bool
    public var checkStatus: Bool
    public var mode: CADMVVerificationMode
    public var networkTimeoutSeconds: Double
}

public enum CADMVVerificationMode: Sendable {
    case production
    case uat
}

public enum CADMVVerifier {
    public static func verify(
        rawPDF417: String,
        options: CADMVVerificationOptions = .default
    ) async -> CADMVVerificationResult
}
```

Open API questions:

- Should callers be able to inject a network client for tests?
- Resolved: status outcomes take precedence over expiration when status checking is required. If the status list marks the credential revoked, return `revoked`; if required status checking is unavailable, return `unavailable`; otherwise return `expired` when credential `validUntil` or proof `expires` has passed.
- What exact shape should the safety-forward debug options take?
- Which operational policy presets should be exposed for implementers, for example offline-only, online-status-required, and custom network policy?

## Architecture Plan

Proposed module layout inside one Swift package:

- `CADMVVerifier`
  - Public API.
  - Result mapping.
  - High-level orchestration.
- `CADMVScanner`
  - Optional iOS barcode scanning target.
  - Camera permission handling.
  - PDF417 detection.
  - Raw barcode string handoff to `CADMVVerifier`.
  - No credential parsing, verification, persistence, or logging.
- `AAMVA`
  - PDF417 input normalization.
  - AAMVA header and subfile parsing.
  - California issuer detection.
  - VCB field extraction.
- `AAMVACanonicalization`
  - Protected component selection.
  - DMV-compatible canonical byte generation.
  - Optical data hash generation.
- `CBORLD`
  - CBOR-LD decoding.
  - DMV registry/type-table metadata.
  - Fail-closed registry handling.
- `VerifiableCredential`
  - Credential models.
  - Shape validation.
  - Issuer, proof, verification method, credential subject, and status checks.
- `DIDWeb`
  - DID Web resolution.
  - Host allowlist enforcement.
  - DID document validation.
  - Optional cache policy.
- `DataIntegrity`
  - `ecdsa-xi-2023` verification.
  - Proof configuration validation.
  - Extra information / optical data hash integration.
- `StatusList`
  - Terse Bitstring Status List resolution.
  - Status-list credential verification.
  - Revocation bit lookup.
- `InternalSecurity`
  - Redacted errors.
  - Constant-time helpers.
  - Sensitive-data handling helpers.
- `TestSupport`
  - Synthetic fixture builders.
  - Reference SDK comparison harness.

The names may change during implementation if Swift Package conventions or dependency boundaries suggest a cleaner shape.

## Implementation Milestones

### Milestone 0: Reference Capture

Goal: freeze the authoritative behavior before writing Swift logic.

Tasks:

- [x] Clone or vendor the official DMV JavaScript SDK for reference.
- [x] Record upstream commit hash.
- [x] Save license and attribution requirements.
- [x] Review DMV technical guide.
- [x] Identify DMV sample fixtures and redistribution rules.
- [x] Build a small reference runner that can execute the JS SDK against fixtures.
- [x] Install reference SDK dependencies locally.
- [x] Run upstream test suite locally and record current result.

Exit criteria:

- Official SDK behavior can be run locally.
- Known fixtures and expected results are documented.
- Legal/fixture redistribution status is known.

Reference harness notes:

- The upstream `package.json` imports `@digitalbazaar/did-io` from `lib/index.js` but does not list it as a dependency at reference commit `03c5485513ff6f2de6b46950a159b8f2cd427859`.
- Local reference checkout patch: add `@digitalbazaar/did-io@2.2.0` so tests can load.
- Local test command uses the bundled Codex Node runtime because `npm` is not on the system shell PATH.
- Test result after adding the missing dependency: 19 passed, 1 failed, 1 todo.
- Failing upstream test: `verifyStatus=true`.
- Failure cause: status check returns `"credentialStatus" property not found.` for the published UAT valid fixture.
- Verification without status checking passes for the same fixture.
- Treat status-check parity as a separate investigation item; do not let this block AAMVA, VCB extraction, CBOR-LD decode, or non-status cryptographic verification work.

### Milestone 1: Package Foundation

Goal: create a modern Swift Package with safe defaults.

Tasks:

- [x] Create `Package.swift`.
- [x] Configure broad Swift platform support for the core verifier.
- [x] Set scanner target availability to iOS 26 first.
- [x] Configure Swift 6.3 language mode where supported.
- [x] Add library target.
- [x] Add optional scanner target/product.
- [x] Add self-test executable target.
- [x] Add strict concurrency settings.
- [x] Add README, NOTICE, and license files.
- [x] Add privacy and security documentation.

Exit criteria:

- [x] Package builds.
- [x] Self-test runner passes.
- [x] Public API shell exists.

Local test-framework note:

- The local Swift 6.3.2 toolchain does not expose Swift `Testing` or `XCTest` to SwiftPM in this environment.
- The package currently uses `CADMVVerifierSelfTest`, a plain Swift executable target, as the repeatable local verification command.
- Revisit a formal `testTarget` when the target CI/toolchain exposes an available test framework.

### Milestone 1A: Optional Barcode Scanner Target

Goal: support apps that want the package to scan PDF417 barcodes directly while keeping the core verifier usable with externally scanned raw barcode data.

Tasks:

- [x] Decide whether the scanner target ships in the same package or a companion package.
- [x] Use native Apple scanning APIs where possible.
- [x] Keep camera/UI dependencies out of the core verifier target.
- [x] Return only raw PDF417 data to the verifier boundary.
- [x] Avoid storing frames, barcode payloads, parsed fields, or decoded credentials.
- [x] Document required camera permissions and app-level privacy copy.
- [x] Add scanner integration examples that immediately pass scanned data into verification and then discard it.

Exit criteria:

- Apps can either pass raw barcode data directly or use an optional scanner flow.
- Non-camera integrations do not depend on camera frameworks.
- Scanner documentation makes PII handling explicit.

### Milestone 2: AAMVA Parsing and VCB Extraction

Goal: reliably identify applicable CA DMV barcode data and extract the VCB payload.

Tasks:

- [x] Parse AAMVA issuer identification number.
- [x] Parse issuing jurisdiction/state.
- [x] Parse issue date.
- [x] Parse subfile structure.
- [x] Detect CA DMV production issuer `636014`.
- [x] Locate `ZC` subfile.
- [x] Extract `ZCE` field.
- [x] Base64-decode VCB bytes.
- [x] Implement VCB requirement date handling.
- [x] Add malformed-input checks in self-test runner.

Exit criteria:

- [x] Missing/not-required VCB maps to `notPresent`.
- [x] Required/malformed VCB maps to `failed`.
- [x] Non-California barcode is not treated as verified.
- [x] Confirm parser against DMV-published fixture.

### Milestone 3: Canonicalization

Goal: match DMV/SDK canonicalization of protected optical barcode data.

Tasks:

- [x] Port or reproduce protected component index handling.
- [x] Port or reproduce AAMVA canonical byte generation.
- [x] Hash canonicalized optical data.
- [x] Compare output against JS `@digitalbazaar/pdf417-dl-canonicalizer`.
- [x] Add tampered-field tests.

Exit criteria:

- [x] Swift canonicalization output matches the reference SDK for available official UAT fixtures.
- Tampered protected AAMVA fields fail verification once crypto is enabled.

### Milestone 4: CBOR-LD Decode

Goal: decode VCB payload into a validated JSON-LD credential shape.

Tasks:

- [x] Inventory DMV registry metadata from JS SDK.
- [x] Implement or select CBOR decoder.
- [x] Implement CBOR-LD table expansion for available DMV VCB fixture shape.
- [x] Add DMV context, cryptosuite, URL, issuer, verification method, and status-list entries.
- [x] Fail closed on unknown registry values.
- [x] Add malformed CBOR-LD tests.

Exit criteria:

- [x] Valid DMV sample VCB decodes.
- Unknown or unsupported registry values fail.

### Milestone 5: Credential Validation

Goal: validate decoded credential structure before cryptography.

Tasks:

- [x] Validate credential type.
- [x] Validate expected optical barcode credential type.
- [x] Validate issuer DID for selected mode.
- [x] Validate proof type and cryptosuite.
- [x] Validate verification method belongs to expected DMV DID.
- [x] Validate `protectedComponentIndex`.
- [x] Validate supported credential status type when status checking is enabled.

Exit criteria:

- Unexpected issuer, cryptosuite, proof, status type, or missing protected component fails before cryptographic verification.

### Milestone 6: DID Web and Data Integrity Verification

Goal: verify `ecdsa-xi-2023` proofs against DMV DID Web documents.

Tasks:

- [x] Implement DID Web URL construction for allowed DMV hosts.
- [x] Implement production and UAT host allowlists.
- [x] Fetch and parse DID documents.
- [x] Validate verification methods.
- [x] Implement `ecdsa-xi-2023` verification for the DMV VCB profile used by available official fixtures.
- [x] Feed optical data hash as required extra information.
- [x] Add network failure handling.
- [x] Add invalid/tampered proof fixture test using DMV invalid UAT sample.

Exit criteria:

- [x] Valid DMV UAT sample verifies.
- [x] Invalid DMV UAT proof fails.
- DID resolution failure fails closed.
- [x] Arbitrary credential URLs are not fetched for DID resolution.

### Milestone 7: Status / Revocation

Goal: implement optional online revocation checking.

Tasks:

- [x] Read `terseStatusListBaseUrl`.
- [x] Read `terseStatusListIndex`.
- [x] Calculate list index and status-list index.
- [x] Build revocation status-list URL.
- [x] Fetch status-list credential only from allowed hosts.
- [x] Verify status-list credential cryptographically.
- [x] Decode status bit from uncompressed status-list bytes.
- [x] Decode gzip/base64url status-list `encodedList`.
- [x] Return `revoked` when the verified revocation bit is set.
- [x] Return `unavailable` when status checking is required but unavailable.
- [x] Return `expired` when verified credential expiration data has passed.
- [x] Add SPI-only status-list profile drift diagnostics for unknown signed fields.

Exit criteria:

- [x] Synthetic valid non-revoked status-list credential returns `verified`.
- [x] Synthetic revoked status-list credential returns `revoked`.
- [x] Status outage returns `unavailable`, not `verified`.

### Milestone 8: Production Hardening

Goal: make the package safe and practical for app integration.

Tasks:

- [x] Add public integration guide.
- [x] Add threat model.
- [x] Add dependency/license audit.
- [x] Add fixture policy.
- [x] Add upstream SDK tracking instructions.
- [x] Add fuzz or property tests for malformed barcode/CBOR inputs.
- [x] Add CI instructions.
- [x] Review all public messages for PII safety.
- [x] Review all errors and debug paths for PII safety.

Exit criteria:

- Package passes tests.
- Documentation is sufficient for app integration.
- Security decisions and limitations are documented.

## Fixture Policy

Do not commit real personal ID data.

Allowed fixtures:

- DMV-published samples if redistribution is permitted.
- Synthetic AAMVA data created specifically for tests.
- Synthetic credentials created specifically for tests.
- Redacted byte-level fixtures that contain no real PII.

Disallowed fixtures:

- Real scans from real driver licenses or ID cards.
- Raw barcode data from any real person.
- Screenshots or photos of real identity documents.
- Debug output containing decoded real credential data.

Fixture open questions:

- Which DMV samples are redistributable?
- Does the DMV provide a revoked public sample?
- Should private local-only fixtures be supported through ignored directories?

## Documentation Deliverables

Required docs:

- [x] README with install and basic usage.
- [x] Security and privacy guide.
- [x] Integration guide for app developers.
- API reference comments.
- [x] Fixture policy.
- [x] Upstream comparison notes.
- [x] NOTICE / attribution file.
- [x] Limitations and unsupported behavior.

Documentation style:

- Clear, direct, and privacy-aware.
- No PII in examples.
- Show safe integration patterns.
- Make status-check behavior explicit.
- Make failure modes explicit.

## Decision Log

### 2026-06-22: Project Priority Order

Decision: Security and safety are the first priority. Modern Swift-native implementation is second priority.

Rationale: The verifier processes government ID barcode data containing PII and makes authenticity decisions. A convenient or fast implementation is not acceptable if it weakens privacy, verification correctness, or fail-closed behavior.

### 2026-06-22: Platform Target

Decision: Target Swift 6.3. Support all platforms that can compile the Swift package and selected dependencies, with iOS 26 as the primary app-integration target and first scanner target.

Rationale: The core verifier should be broadly usable wherever Swift can compile it. Camera scanning is inherently platform-specific, so scanner code should be isolated while the verifier stays portable.

### 2026-06-22: Swift-Native Preference

Decision: Implement as much as possible in Swift. Non-Swift fallbacks require explicit documentation and narrow isolation.

Rationale: A Swift-native package is easier for iOS/macOS apps to audit, integrate, and maintain. Some standards involved may not have mature Swift implementations, so the plan allows carefully controlled fallbacks only when necessary.

### 2026-06-23: Official SDK Reference

Decision: The official JavaScript SDK may be cloned or vendored into `References/cadmv-dlid-verifier-sdk/` for behavior comparison and attribution tracking.

Reference commit: `03c5485513ff6f2de6b46950a159b8f2cd427859`

Rationale: The Swift verifier must match DMV SDK behavior where possible. Keeping the reference SDK local makes parity testing, registry extraction, license review, and upstream audits concrete.

License notes:

- The SDK is BSD-3-Clause.
- Copyright notices include California Department of Motor Vehicles and Digital Bazaar, Inc.
- Derived distributions must retain the license notice and must not imply endorsement by copyright holders or contributors.

### 2026-06-23: Reference Harness Patch

Decision: The local reference checkout may carry a documented harness-only dependency patch if needed to run upstream tests.

Current patch: add missing dependency `@digitalbazaar/did-io@2.2.0`.

Rationale: The official SDK imports `@digitalbazaar/did-io`, but the dependency is not declared at the captured commit. The patch makes local parity testing possible while preserving the recorded upstream commit as the authority.

### 2026-06-23: Scanner Packaging

Decision: Barcode scanning should ship as a separate optional target/product, recommended name `CADMVScanner`, in the same Swift package unless implementation details force a companion package later.

Rationale: This keeps the core verifier free of camera and UI dependencies while still giving app developers a native scanner path.

### 2026-06-23: Scanner Technology

Decision: Use native Apple scanning APIs first for iOS 26, with VisionKit/DataScanner preferred where appropriate. Use AVFoundation only if needed for control, compatibility, or scanner quality.

Rationale: Native APIs reduce dependency and maintenance risk. Lower-level scanning should be added only when it provides a concrete benefit.

### 2026-06-23: Status Check Default

Decision: `checkStatus` should default to `false` at the library level. High-assurance apps should be documented to enable it. When enabled and status infrastructure is unavailable, verification must return `unavailable`, not `verified`.

Rationale: Status checks require network access and operational policy decisions. The library should make the safer high-assurance path clear without surprising every integration with network dependence by default.

### 2026-06-23: Debug Options

Decision: Implementers should have debug options, but the design must be safety-forward. Debug output must be opt-in, clearly marked sensitive, and constrained so production integrations do not accidentally log PII.

Rationale: Debug visibility is important during integration and parity testing, but this package handles PII. Debugging must be deliberately enabled and documented as unsafe for routine telemetry or logs.

### 2026-06-23: Implementer Policy Options

Decision: The package should give implementers clear operational choices instead of forcing one universal policy. The defaults and documentation must remain safety-forward.

Recommended options:

- Offline signature check: validates structure and DMV VCB signature without online revocation. This is useful when network use is not allowed, but should be documented as lower assurance.
- Online status required: validates structure, signature, DID material, and revocation status. This should be recommended for high-assurance use and must return `unavailable` if the status check cannot be completed safely.
- Custom network policy: allows an app to configure timeouts and, if later exposed, dependency injection for approved test clients without weakening DMV host allowlists by default.

Rationale: Real integrations have different network, latency, and policy constraints. The library should support those choices while making the security tradeoff visible.

### 2026-06-23: Verification Input Modes

Decision: The verifier must support both already scanned raw PDF417 barcode data and package-provided barcode scanning.

Rationale: Some apps will use camera scanning, while others will receive data from dedicated barcode hardware, existing scanner SDKs, backend systems, or tests. Keeping raw payload verification as the core API prevents scanner/UI dependencies from becoming mandatory and keeps PII lifetime easier to control.

### 2026-06-23: License Compliance Constraint

Decision: The fork may use the official DMV JavaScript repository as a reference as long as the implementation follows the upstream license and preserves required notices.

Rationale: Reference parity is important, but redistributed source, derived documentation, and attribution must remain compliant with the BSD-3-Clause terms and any other dependency licenses.

### 2026-06-23: Cache Policy

Decision: The package does not persist or cache DID documents, status-list credentials, raw barcode data, parsed AAMVA fields, or decoded credentials.

Rationale: No-cache behavior is the safest current default for PII-adjacent verification. If cache support is added later, it must be explicit, documented, bounded by a caller-approved policy, and covered by tests.

## Future Release Questions

- Should debug details require a compile-time flag?
- Should debug details also require an explicit runtime option?
- Should the package expose a lower-level parser API, or only the high-level verifier?
- What minimum CI environment will have Swift 6.3 / iOS 26 SDK support?
- Which non-Apple platforms should receive active CI coverage after the core verifier compiles?
- Should the reference SDK be committed in full, added as a git submodule, or cloned by a setup script before CI/reference testing?
- Should `CADMVVerifierSelfTest` remain after CI has a real test framework available, or become a supplementary smoke-test tool?
- Should `status.uat-credentials.dmv.ca.gov` be added to the UAT allowlist if DMV status endpoints now redirect there?
- Can DMV provide a redistributable live-format revoked status-list fixture for end-to-end `.revoked` testing without relying on current UAT infrastructure?

## Progress Log

### 2026-06-22

- Reviewed the existing requirements document.
- Confirmed the workspace contains only the requirements document and git metadata.
- Created this planning document.

### 2026-06-23

- Recorded implementation decisions from the project owner.
- Cloned the official JavaScript SDK into `References/cadmv-dlid-verifier-sdk/`.
- Recorded upstream reference commit `03c5485513ff6f2de6b46950a159b8f2cd427859`.
- Reviewed SDK package metadata, README, license, core `lib/index.js`, and test fixture file.
- Confirmed official SDK keeps scanning out of scope; this Swift fork will include scanning as an optional layer.
- Confirmed official SDK restricts network loading to DMV hosts by mode.
- Confirmed official SDK uses `ecdsa-xi-2023` for VCB verification and `ecdsa-rdfc-2019` for Bitstring Status List credential verification.
- Installed reference dependencies with bundled `pnpm`.
- Added local reference-harness dependency patch for missing `@digitalbazaar/did-io@2.2.0`.
- Ran upstream tests: 19 passed, 1 failed, 1 todo.
- Captured current failing upstream status-check behavior for later investigation.
- Scaffolded Swift package with `CADMVVerifier`, `CADMVScanner`, and `CADMVVerifierSelfTest` products.
- Implemented privacy-minimized public verifier API.
- Implemented early AAMVA parser, California DMV issuer/state detection, VCB field extraction, VCB requirement-date handling, and base64url decode gate.
- Added README, security/privacy guide, integration guide, NOTICE, LICENSE, fixture policy note, and `.gitignore`.
- Confirmed `swift build` succeeds.
- Confirmed `swift run CADMVVerifierSelfTest` passes.
- Corrected scanner availability so it reports unavailable until native camera scanning is implemented.
- Added public API documentation comments for privacy and verification semantics.
- Added SPI-only self-test inspection that exposes non-PII parity fields for official fixtures without expanding the normal public API.
- Added native fail-closed CBOR reader and DMV VCB decoder for the available official UAT credential shape.
- Added credential-shape validation for UAT and production issuer/status/proof policy.
- Ported AAMVA protected-component selection and canonical SHA-256 hashing.
- Fixed AAMVA parser bug by stripping subfile designators before field parsing; this restored protected `DAQ` parsing.
- Confirmed Swift optical data hashes match the JS reference SDK for valid and invalid DMV UAT fixtures.
- Confirmed `swift build` and `swift run CADMVVerifierSelfTest` pass after CBOR-LD, validation, and canonicalization work.
- Added DID Web resolver with explicit production/UAT DMV DID-document URLs.
- Added Multikey base58btc decode and compressed P-256 key extraction.
- Confirmed live UAT and production DMV DID documents resolve `#vm-vcb-1` to expected compressed public keys.
- Confirmed `swift build` and `swift run CADMVVerifierSelfTest` pass after DID resolution work.
- Implemented narrow native `ecdsa-xi-2023` verification for the DMV VCB JSON-LD shape used in official fixtures.
- Reproduced JS reference verify-data bytes for the valid DMV UAT fixture.
- Confirmed Swift verifier returns `verified` for the official valid DMV UAT sample with status checking disabled.
- Confirmed Swift verifier returns `failed` for the official invalid DMV UAT sample.
- Checked UAT status-list URL derived from the valid fixture; it redirects to `status.uat-credentials.dmv.ca.gov` and currently returns 404 after following the redirect.
- Kept `checkStatus=true` mapped to `unavailable` after successful signature verification while live DMV UAT status infrastructure remained unusable.
- Added iOS VisionKit PDF417 scanner wrapper in the optional `CADMVScanner` target.
- Confirmed `swift build` and `swift run CADMVVerifierSelfTest` pass after scanner wrapper work.
- Added status-list URL calculation for `TerseBitstringStatusListEntry`.
- Added status-list fetch boundary with explicit DMV API host allowlist and redirect suppression.
- Confirmed status-required valid UAT verification returns `unavailable` instead of `verified`.
- Confirmed `swift build` and `swift run CADMVVerifierSelfTest` pass after status-list boundary work.
- Added self-test coverage for malformed CBOR-LD, protected AAMVA tampering, UAT credential rejection in production mode, and DID mode mismatch.
- Added threat model, dependency/license audit, upstream tracking, CI notes, and camera-permission integration guidance.
- Added deterministic malformed barcode corpus to `CADMVVerifierSelfTest`.
- Ran safety scans for production logging/debug/error-message risks; normal public API remains privacy-minimized and no public debug surface is exposed.
- Confirmed `swift build`, `swift build -c release`, and `swift run CADMVVerifierSelfTest` pass.
- Added `Tools/reference-runner.mjs` for privacy-minimized JS SDK fixture parity output.
- Reviewed DMV technical guide `REV DEC25` and added `Docs/TECHNICAL_GUIDE_REVIEW.md`.
- Added exact status-list bit-index calculation and self-test assertion for the valid UAT fixture.
- Confirmed `swift build`, `swift run CADMVVerifierSelfTest`, and `node Tools/reference-runner.mjs` pass.
- Added status-list bit-order decoder matching Digital Bazaar bitstring behavior and synthetic self-test coverage.
- Added zlib-backed gzip decompression for Bitstring Status List `encodedList` values.
- Confirmed encoded-list decoding against a synthetic value generated by the Digital Bazaar status-list library.
- Added public API documentation and final review notes.
- Finalized the security model for the current verifier surface: privacy-minimized public API, no public debug data, explicit DMV host policies, and fail-closed status-required behavior.
- Added a shared ephemeral no-redirect network session for DID and status-list fetches.
- Added portable `FoundationNetworking` imports for URLSession-based verifier code.
- Generated a synthetic Bitstring Status List credential with the Digital Bazaar JavaScript stack and captured its `ecdsa-rdfc-2019` verify-data vector.
- Implemented narrow native `ecdsa-rdfc-2019` verification for the supported DMV VC v2 Bitstring Status List credential profile.
- Wired verified status-list credentials into revocation bit lookup so verified set bits return `revoked` and verified clear bits return `verified`.
- Added self-test coverage for status-list verify-data parity, proof verification, tampered encoded-list failure, revoked mapping, and not-revoked mapping.
- Added strict status-list string validation before native N-Quads generation to reject values that would require escaping or could alter canonicalization.
- Added self-test coverage for unsafe status-list canonicalization input rejection.
- Recorded no-cache policy for DID documents, status-list credentials, raw barcodes, parsed AAMVA fields, and decoded credentials.
- Added Apple `swift-crypto` for CryptoKit-compatible APIs on non-Apple Swift platforms and recorded resolved dependency versions/licenses.
- Refactored P-256 proof verification into a shared helper used by both `ecdsa-xi-2023` and `ecdsa-rdfc-2019`.
- Reused a single ephemeral no-redirect `URLSession` instead of constructing a session per network request.
- Added a CBOR nesting-depth limit and self-test coverage for deeply nested malformed CBOR.
- Replaced regex-based status-list and AAMVA field validation with direct ASCII checks.
- Optimized Base58 decoding with a byte lookup table and fixed leading-zero encode/decode round trips.
