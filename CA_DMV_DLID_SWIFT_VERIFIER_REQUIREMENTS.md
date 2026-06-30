# California DMV DL/ID Digital Signature Swift Verifier Requirements

## Purpose

Define the requirements for a general-purpose Swift verifier for California DMV driver license and identification card digital signatures embedded in PDF417 barcodes.

The verifier should be usable by any Swift/iOS/macOS application that scans or receives raw PDF417 data and needs to determine whether a California DL/ID barcode contains a valid Verifiable Credential Barcode (VCB), whether the credential cryptographically verifies, and whether the credential has been revoked when status checking is enabled.

This document is intentionally app-agnostic. It does not depend on a specific notary, journal, backend, UI, or data model.

## Authoritative References

Use these as source material for behavior and test expectations:

- California DMV Digital Signature page: `https://www.dmv.ca.gov/portal/driver-licenses-identification-cards/digital-signature/`
- California DMV technical guide PDF: `https://www.dmv.ca.gov/portal/file/verifying-digital-signatures-on-california-dlid-documents-pdf/`
- Official SDK: `https://github.com/stateofca/cadmv-dlid-verifier-sdk`
- Verifiable Credential Barcodes: `https://w3c-ccg.github.io/vc-barcodes/`
- CBOR-LD 1.0
- Bitstring Status List 1.0
- Verifiable Credential Data Integrity 1.0
- Verifiable Credentials Data Model 2.0
- Decentralized Identifiers 1.0
- AAMVA PDF417 driver license/identification card barcode format

When this document conflicts with DMV’s guide or official SDK behavior, follow DMV’s published guide and SDK.

## Product Shape

Build the verifier as a standalone Swift Package, not as app-specific source files.

Suggested package name:

```text
CADMVVerifier
```

Suggested products:

```swift
.library(name: "CADMVVerifier", targets: ["CADMVVerifier"])
```

Suggested platforms:

```swift
.iOS(.v16)
.macOS(.v13)
```

The package should avoid dependencies on UIKit, SwiftUI, SwiftData, app storage, app auth, or app logging systems.

## Public API

Provide a small, stable API that accepts raw PDF417 data and returns a privacy-minimized result.

Suggested shape:

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

The public API should not expose raw parsed PII by default. If debug details are added later, they must be opt-in, clearly marked unsafe for production logging, and excluded from normal app telemetry.

## Required Behavior

### AAMVA Parsing

The verifier must parse raw PDF417 data according to AAMVA DL/ID rules.

It must extract at least:

- Issuer Identification Number (IIN)
- Issuing jurisdiction/state (`DAJ`)
- Issue date (`DBD`)
- DL/ID subfile data
- California VCB subfile and field

California production DL/ID issuer requirements from the official SDK:

```text
Issuer Identification Number: 636014
Issued state: CA
VCB subfile: ZC
VCB field: ZCE
```

The verifier must reject non-California issuers as not applicable or failed, depending on the chosen result taxonomy. The recommended public result is `notPresent` with a message such as "California DMV digital signature is not present." if the document is not a California VCB document.

### VCB Requirement Date

California DL/ID documents issued on or after the DMV-defined VCB requirement date must contain a VCB. The official SDK currently uses:

```text
09/29/2025
```

Documents issued before that date may be valid physical IDs without a VCB. The verifier should return `notPresent` rather than `failed` when VCB is not required and absent.

If `requireVCB` is true, missing VCB data must fail even for older documents.

### VCB Extraction

The verifier must:

- Locate the `ZC` subfile.
- Extract the `ZCE` field.
- Base64-decode the field value.
- Treat missing, malformed, or undecodable VCB data as a distinct verification failure.

### CBOR-LD Decode

The verifier must decode the VCB payload from CBOR-LD to JSON-LD Verifiable Credential form.

The implementation must include the DMV registry/type-table metadata used by the official SDK. At minimum, it must support:

- Context table entries for:
  - `https://www.w3.org/ns/credentials/v2`
  - `https://w3id.org/vc-barcodes/v1`
- Cryptosuite table entry:
  - `ecdsa-xi-2023`
- Production URL table entries for:
  - `did:web:credentials.dmv.ca.gov`
  - production status-list base URLs
  - production verification method IDs `#vm-vcb-1` through currently published values
- UAT URL table entries used by DMV sample/test credentials

The decoder must fail closed. Unknown unsupported registry values must not be treated as verified.

### Credential Shape Validation

The decoded credential must be validated before cryptographic verification. Required checks:

- Credential type includes `VerifiableCredential`.
- Credential type includes the expected optical barcode credential type.
- Issuer is the expected DMV DID for the selected mode.
- Proof exists and has the expected type and cryptosuite.
- Verification method belongs to the expected DMV DID.
- Credential subject includes `protectedComponentIndex`.
- Credential status, when present and status checking is enabled, uses a supported status-list type.

Production mode must enforce:

```text
Issuer DID: did:web:credentials.dmv.ca.gov
DID document: https://credentials.dmv.ca.gov/.well-known/did.json
Status-list prefix: https://api.credentials.dmv.ca.gov/status/dlid
```

UAT mode must enforce the corresponding UAT hosts.

### AAMVA Canonicalization and Optical Data Hash

The digital signature does not sign only the credential. It also signs protected AAMVA barcode data.

The verifier must:

- Use `credentialSubject.protectedComponentIndex` to select the protected AAMVA component.
- Canonicalize the selected AAMVA fields exactly as DMV’s SDK and technical guide require.
- Hash the canonicalized data.
- Provide that hash as the extra information required by the `ecdsa-xi-2023` cryptosuite verification.

This is a critical correctness point. A mismatch here can cause false failures or, worse, false passes.

### Cryptographic Verification

The verifier must implement Data Integrity verification for:

```text
ecdsa-xi-2023
```

It must resolve DMV DID Web documents and use the verification method referenced by the credential proof.

Cryptographic verification must fail closed when:

- DID resolution fails.
- The verification method is absent.
- The key type is unsupported.
- The proof is malformed.
- The signature does not verify.
- Required extra information / optical data hash is unavailable.

### Revocation / Status Check

When `checkStatus` is true, the verifier must check the credential status.

The DMV SDK supports `TerseBitstringStatusListEntry`. The Swift verifier must:

- Read `terseStatusListBaseUrl`.
- Read `terseStatusListIndex`.
- Calculate:

```text
listIndex = floor(terseStatusListIndex / 67108864)
statusListIndex = terseStatusListIndex % 67108864
```

- Build the status-list URL with status purpose `revocation`.
- Fetch the Bitstring Status List credential.
- Verify the status-list credential cryptographically.
- Check the relevant bit.
- Return `revoked` when the bit indicates revocation.

If status checking is disabled, successful cryptographic verification may return `verified` without a revocation check. The result message should make this clear only if the caller asks for detail.

If status checking is enabled but the status infrastructure is temporarily unreachable, return `unavailable`, not `verified`.

### Expiration Handling

The verifier must distinguish expired credentials from invalid signatures and revoked credentials when expiration data is available in the credential.

Recommended mapping:

- Signature verifies and status not revoked, but credential expired: `expired`
- Signature fails: `failed`
- Status list says revoked: `revoked`
- Status infrastructure unreachable: `unavailable`
- VCB absent and not required: `notPresent`

## Networking Requirements

The verifier should support verification with and without network access:

- Offline cryptographic verification: DID/key material and contexts may be cached or bundled.
- Online status verification: requires status-list fetch unless cached status-list data is still valid under an explicit cache policy.

Network access must be restricted to DMV-controlled hosts for the selected mode.

Production allowed hosts:

```text
credentials.dmv.ca.gov
api.credentials.dmv.ca.gov
```

UAT allowed hosts:

```text
uat-credentials.dmv.ca.gov
api.uat-credentials.dmv.ca.gov
```

The package must not fetch arbitrary URLs embedded in untrusted credentials.

## Privacy Requirements

Raw PDF417 barcode data contains personally identifiable information.

The verifier package must:

- Avoid logging raw barcode data.
- Avoid logging parsed ID fields.
- Avoid logging decoded credential payloads in production.
- Avoid storing raw barcode data.
- Avoid storing parsed PII.
- Keep debug output opt-in and clearly documented as sensitive.
- Provide privacy-minimized public results by default.

Apps using the verifier should process raw barcode data in memory and discard it as soon as verification completes, unless the app has a separate, legally justified retention policy.

## Error and Result Messages

Messages should be plain-language and safe to show to users or auditors. They must not include PII or raw credential material.

Recommended messages:

- `verified`: "DMV digital-signature verification passed."
- `notPresent`: "California DMV digital signature is not present."
- `failed`: "DMV digital-signature verification failed."
- `revoked`: "This DMV digital credential has been revoked."
- `expired`: "This DMV digital credential is expired."
- `unavailable`: "DMV digital-signature verification is temporarily unavailable."

More detailed technical errors may be available internally for tests, but should remain redacted.

## Test Requirements

The package must include a focused test suite before production use.

Required fixture categories:

- DMV-published valid sample barcode.
- DMV-published revoked sample barcode, if available.
- California barcode issued before the VCB requirement date with no VCB.
- California barcode issued after the requirement date with no VCB.
- Non-California AAMVA barcode.
- Malformed AAMVA barcode.
- Malformed base64 VCB.
- Malformed CBOR-LD VCB.
- VCB with unexpected issuer DID.
- VCB with unsupported cryptosuite.
- VCB with tampered protected AAMVA field.
- Valid signature with status check disabled.
- Valid signature with status service unavailable.

Tests must cover both production and UAT mode where fixtures are available.

No real person’s ID data should be committed as a fixture. Use only DMV-published samples, generated test credentials, or synthetic data explicitly designed for testing.

## Security Requirements

The verifier is security-sensitive. Implementation rules:

- Fail closed.
- Do not ignore unsupported cryptographic fields.
- Do not downgrade verification silently.
- Keep allowed network hosts explicit.
- Verify DID documents and status-list credentials according to spec.
- Make cache behavior explicit.
- Use constant-time comparison where comparing sensitive hashes/signatures directly.
- Avoid global mutable state unless protected and testable.
- Keep dependencies pinned.
- Track upstream DMV SDK changes and update behavior intentionally.

## Licensing and Attribution

The official DMV SDK is published under BSD-3-Clause. A Swift port should:

- Preserve required copyright and license notices.
- Include a `NOTICE` or equivalent attribution file.
- State clearly whether the Swift package is official, unofficial, or internally maintained.
- Avoid implying endorsement by California DMV or Digital Bazaar unless explicitly granted.

Suggested package documentation wording:

```text
This package is a Swift implementation intended to match behavior from the California DMV DL/ID verifier SDK and technical guide. It is not endorsed by California DMV unless separately stated.
```

## Deliverables

Minimum useful deliverables:

- Swift Package manifest.
- AAMVA parser/canonicalizer module.
- VCB extraction module.
- CBOR-LD decoder module with DMV registry metadata.
- Verifiable Credential model/validator.
- DID Web resolver with host allowlist.
- Data Integrity verifier for `ecdsa-xi-2023`.
- Bitstring status-list checker.
- Public verification API.
- Redacted error/result model.
- Unit test suite with public/synthetic fixtures.
- License and attribution files.
- Integration guide for client applications.

## Acceptance Criteria

The Swift verifier is ready for app integration when:

- It returns `verified` for DMV’s valid sample fixture.
- It returns `revoked` for DMV’s revoked sample fixture when available.
- It rejects tampered AAMVA data.
- It rejects tampered VCB/proof data.
- It distinguishes missing VCB from failed signature.
- It enforces production issuer and status-list hosts.
- It performs status checks when requested.
- It returns `unavailable` instead of `verified` when required online status checks cannot complete.
- It has no production logging of raw barcode data or parsed PII.
- It has tests for every result status.
- Its behavior is compared against the official JavaScript SDK for the same fixtures.

## Integration Guidance for Apps

Apps should treat this package as a verifier, not as a source of truth for identity data entry.

Recommended app flow:

1. Scan PDF417 barcode.
2. Parse ID fields separately for data entry/review.
3. Pass the raw PDF417 string to `CADMVVerifier.verify`.
4. Store only the verification status and safe message unless the app has a separate retention need.
5. Never log the raw barcode or decoded credential.
6. Let users proceed with manual review if verification is unavailable, according to the app’s business/legal rules.

## Open Questions

Resolve these before production release:

- Should the verifier require online revocation checks by default?
- What cache policy is acceptable for DID documents and status lists?
- Which DMV sample fixtures can be redistributed in the test suite?
- Resolved: expired credentials map to `expired` after signature verification and any required revocation check succeeds as not revoked.
- Should the package expose debug details under a compile-time flag only?
- How will upstream DMV SDK changes be tracked and audited?
