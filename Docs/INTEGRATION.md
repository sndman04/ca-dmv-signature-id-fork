# Integration Guide

## Core Verifier Flow

Apps that already have raw PDF417 data can call the verifier directly:

```swift
let result = await CADMVVerifier.verify(rawPDF417: rawPDF417)
```

The verifier does not expose parsed identity fields. Apps that need identity data for business workflows should parse and handle that data separately under their own retention and privacy policy.

For non-verified results, `result.failureReason` provides a privacy-safe diagnostic such as `malformedBarcode`, `environmentMismatch`, `vcbBase64Invalid`, `didResolutionFailed`, or `signatureMismatch`. Use it for app routing and coarse telemetry only; do not attach raw barcode data, decoded AAMVA fields, proof values, DID documents, or status-list contents.

## Scanner Flow

Apps that want package-provided scanning should use the optional scanner product. The scanner boundary should only capture PDF417 data and hand it to the verifier.

On iOS, the scanner product includes a VisionKit PDF417 wrapper. Other integrations can use the safe boundary type for payloads produced by app-owned scanning code or hardware scanners.

Apps using camera scanning must provide their own `NSCameraUsageDescription` in the app bundle. The permission copy should explain that the camera is used to scan PDF417 barcode data from a DL/ID and that the app should not retain raw barcode data unless the app has a separate retention policy.

Scanner implementations must not:

- Store camera frames.
- Store raw barcode payloads.
- Log barcode payloads.
- Parse identity fields for display or telemetry.
- Log sensitive document data while handling verifier failure reasons.

## Status Checking

`checkStatus` defaults to `false`.

High-assurance applications should enable status checking:

```swift
let options = CADMVVerificationOptions(checkStatus: true)
let result = await CADMVVerifier.verify(rawPDF417: rawPDF417, options: options)
```

When status checking is enabled and DMV status infrastructure is unavailable, the verifier must return `.unavailable`, not `.verified`.

## Current Limitation

The official DMV UAT sample currently derives a status-list URL that redirects and then fails to provide a usable status-list credential. In that case the verifier returns `.unavailable`. Do not treat `.unavailable` as `.verified`.
