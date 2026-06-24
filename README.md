# CADMVVerifier

`CADMVVerifier` is a Swift-native package for verifying California DMV DL/ID digital signatures embedded in PDF417 barcode data.

This repository is under active implementation. It currently includes:

- A Swift Package targeting Swift 6.0.
- A privacy-minimized public verifier API.
- AAMVA PDF417 parsing for issuer, subfile, issue-date, state, and VCB extraction.
- California DMV VCB requirement-date handling.
- An optional scanner target boundary.
- A self-test executable that uses synthetic non-PII data and DMV-published UAT samples from the reference SDK.
- A local reference copy of the official JavaScript SDK for parity work.

This package is a narrow California DMV DL/ID VCB profile verifier, not a general Data Integrity, JSON-LD, or RDF canonicalization library. The native canonicalization code is intentionally limited to the DMV credential and status-list shapes covered by the official UAT fixtures and synthetic JS-reference status-list fixture.

Cryptographic verification is implemented for the DMV VCB profile covered by the official UAT samples. The supported VCB profile accepts a `protectedComponentIndex` encoded as `u` plus a 24-bit bitmap, and the reference canonicalizer's equivalent numeric 24-bit form. Status-list credential verification is implemented for the supported DMV VC v2 profile and returns `.revoked` only after the status-list credential proof verifies. The official UAT sample still returns `.unavailable` with `checkStatus` enabled because the live DMV UAT status endpoint currently does not provide a usable status-list credential.

## Products

- `CADMVVerifier`: core verifier. It accepts already scanned raw PDF417 data.
- `CADMVScanner`: optional scanner boundary. On iOS it includes a VisionKit PDF417 scanner wrapper; non-camera integrations can pass raw PDF417 payloads directly.
- `CADMVVerifierSelfTest`: executable verification runner for this workspace.

## Basic Usage

```swift
import CADMVVerifier

let result = await CADMVVerifier.verify(rawPDF417: scannedPdf417Data)

switch result.status {
case .verified:
    // DMV digital-signature verification passed.
case .notPresent:
    // No applicable CA DMV digital signature was present.
case .failed, .revoked, .expired, .unavailable:
    // Handle according to app policy. Use result.failureReason for
    // privacy-safe diagnostics without logging raw document data.
}
```

## Safety Rules

Raw PDF417 data can contain personally identifiable information.

- Do not log raw barcode data.
- Do not log parsed AAMVA fields.
- Do not persist raw barcode data unless your application has a separate legal basis.
- Store only privacy-minimized verification results unless your application policy requires more.
- Treat `unavailable` differently from `verified`.

## Verification

Run the SwiftPM tests and the broader fixture-backed self-test:

```sh
swift test
swift run CADMVVerifierSelfTest
```

CI runs both commands on push and pull request. The self-test contains the official valid/invalid UAT fixture parity checks, so do not treat `swift test` alone as the full verification gate.

If `swift test` cannot import Swift `Testing` when using Command Line Tools, point SwiftPM at the full Xcode toolchain:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## Reference SDK

The official JavaScript SDK is cloned under:

```text
References/cadmv-dlid-verifier-sdk
```

Initial parity target:

```text
03c5485513ff6f2de6b46950a159b8f2cd427859
```

See `CADMV_SWIFT_VERIFIER_PLAN.md` for progress, decisions, known SDK harness notes, and remaining milestones.

Additional docs:

- `Docs/SECURITY_AND_PRIVACY.md`
- `Docs/API.md`
- `Docs/TECHNICAL_GUIDE_REVIEW.md`
- `Docs/THREAT_MODEL.md`
- `Docs/DEPENDENCY_AND_LICENSE_AUDIT.md`
- `Docs/UPSTREAM_TRACKING.md`
- `Docs/CI.md`
- `Docs/FINAL_REVIEW.md`
