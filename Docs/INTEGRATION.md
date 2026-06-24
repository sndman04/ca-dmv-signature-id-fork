# Integration Guide

## Core Verifier Flow

Apps that already have raw PDF417 data can call the verifier directly:

```swift
let result = await CADMVVerifier.verify(rawPDF417: rawPDF417)
```

Pass the scanner-provided PDF417 string directly. On iOS, that is typically
`AVMetadataMachineReadableCodeObject.stringValue`. The verifier expects the
full AAMVA payload, not a parsed-and-reconstructed string and not a subset of
fields. Do not normalize `\r`, `\u{001d}`, `\u{001e}`, or other AAMVA
separators before verification. Trimming only leading/trailing whitespace and
newlines is supported.

The verifier does not expose parsed identity fields. Apps that need identity data for business workflows may parse a separate copy of the scan under their own retention and privacy policy, but they should keep the original scanner string for `CADMVVerifier.verify`.

For non-verified results, `result.failureReason` provides a privacy-safe diagnostic such as `malformedBarcode`, `environmentMismatch`, `vcbBase64Invalid`, `didResolutionFailed`, or `signatureMismatch`. Use it for app routing and coarse telemetry only; do not attach raw barcode data, decoded AAMVA fields, proof values, DID documents, or status-list contents.

## App Handoff Checklist

Recommended app flow:

1. Capture the PDF417 string from the scanner.
2. Store that exact string in memory for verification.
3. Optionally parse a separate copy for display or form fill.
4. Pass the original string, or only `trimmingCharacters(in: .whitespacesAndNewlines)` applied to it, to `CADMVVerifier.verify`.
5. Discard the raw string as soon as the app no longer needs it.

Do not pass OCR text, a normalized field map, a reconstructed AAMVA string, the VCB field alone, or a string where AAMVA separator characters have been replaced for UI parsing.

## Modes and Test Credentials

`CADMVVerificationOptions` defaults to `.production`. Production mode accepts only production DMV issuer, DID, key, and status hosts.

Use `.uat` only for DMV UAT/test credentials:

```swift
let options = CADMVVerificationOptions(mode: .uat)
let result = await CADMVVerifier.verify(rawPDF417: rawPDF417, options: options)
```

A UAT credential checked in production mode returns `.failed` with `failureReason == .environmentMismatch(expected: .production)`. A production credential checked in UAT mode returns `.failed` with `failureReason == .environmentMismatch(expected: .uat)`.

## VCB Requirement Policy

`requireVCB` defaults to `false`. With the default, a California DL/ID issued before the DMV requirement date can return `.notPresent` if no VCB field exists. The verifier still requires VCB data for California documents issued on or after the requirement date.

Set `requireVCB: true` only when your app policy requires signed DMV data for every scanned California DL/ID, including older documents:

```swift
let options = CADMVVerificationOptions(requireVCB: true)
```

## Scanner Flow

Apps that want package-provided scanning should use the optional scanner product. The scanner boundary should only capture PDF417 data and hand it to the verifier.

On iOS, the scanner product includes a VisionKit PDF417 wrapper. Other integrations can use the safe boundary type for payloads produced by app-owned scanning code or hardware scanners.

Apps using camera scanning must provide their own `NSCameraUsageDescription` in the app bundle. The permission copy should explain that the camera is used to scan PDF417 barcode data from a DL/ID and that the app should not retain raw barcode data unless the app has a separate retention policy.

Scanner implementations must not:

- Store camera frames.
- Store raw barcode payloads.
- Log barcode payloads.
- Parse identity fields inside the reusable scanner component.
- Log sensitive document data while handling verifier failure reasons.

## Status Checking

`checkStatus` defaults to `false`.

High-assurance applications should enable status checking:

```swift
let options = CADMVVerificationOptions(checkStatus: true)
let result = await CADMVVerifier.verify(rawPDF417: rawPDF417, options: options)
```

When status checking is enabled and DMV status infrastructure is unavailable, the verifier must return `.unavailable`, not `.verified`.

Applications should treat only `result.status == .verified` as a successful DMV digital-signature verification. Keep `.unavailable`, `.failed`, `.revoked`, `.expired`, and `.notPresent` distinct in app state and telemetry.

## Current Limitation

The official DMV UAT sample currently derives a status-list URL that redirects and then fails to provide a usable status-list credential. In that case the verifier returns `.unavailable`. Do not treat `.unavailable` as `.verified`.
