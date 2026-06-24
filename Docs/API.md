# Public API

The public API is intentionally small and privacy-minimized.

This package verifies the supported California DMV DL/ID VCB profile. It is not a general JSON-LD/Data Integrity verifier. The current profile support accepts DMV VCB `protectedComponentIndex` values encoded as `u` plus a 24-bit bitmap, and the reference canonicalizer's equivalent numeric 24-bit form; credentials outside that profile fail closed as unsupported.

## `CADMVVerifier`

```swift
public enum CADMVVerifier {
    public static func verify(
        rawPDF417: String,
        options: CADMVVerificationOptions = .default
    ) async -> CADMVVerificationResult
}
```

`rawPDF417` may contain personally identifiable information. The verifier does not log, persist, or expose parsed identity fields.

`rawPDF417` is expected to be the full scanner-provided PDF417 payload. App
integrations should pass values like `AVMetadataMachineReadableCodeObject.stringValue`
directly, without parsing and reconstructing the barcode, normalizing AAMVA
separator characters, or extracting only selected fields. Leading/trailing
whitespace and newline trimming is tolerated.

## `CADMVVerificationOptions`

```swift
public struct CADMVVerificationOptions: Sendable {
    public var requireVCB: Bool
    public var checkStatus: Bool
    public var mode: CADMVVerificationMode
    public var networkTimeoutSeconds: Double
}
```

Defaults:

- `requireVCB = false`
- `checkStatus = false`
- `mode = .production`
- `networkTimeoutSeconds = 10`

`checkStatus = true` performs online revocation checking. If the DMV status endpoint is unavailable, redirects outside the allowed fetch policy, returns an unsupported credential shape, or the status-list credential proof cannot be verified, the result is `.unavailable`. Application integrations should treat only `.verified` as verified.

## `CADMVVerificationResult`

```swift
public struct CADMVVerificationResult: Equatable, Sendable {
    public let status: CADMVVerificationStatus
    public let message: String?
    public let failureReason: CADMVVerificationFailureReason?
}
```

`failureReason` is a privacy-safe diagnostic for non-verified results. It never contains raw barcode data, decoded AAMVA fields, proof values, DID documents, or status-list contents.

## `CADMVVerificationStatus`

```swift
public enum CADMVVerificationStatus: Equatable, Sendable {
    case verified
    case failed
    case notPresent
    case revoked
    case expired
    case unavailable
}
```

Current behavior:

- `.verified`: signature verification passed for the supported DMV VCB profile, and status checking either was disabled or verified the credential as not revoked.
- `.failed`: malformed data, unsupported data, issuer/mode mismatch, invalid signature, or required VCB missing.
- `.notPresent`: non-California or pre-requirement-date document without VCB.
- `.unavailable`: required status checking cannot complete.
- `.revoked`: a cryptographically verified status-list credential marks the revocation bit as set.
- `.expired`: reserved for credential expiration handling when expiration data is available.

## `CADMVVerificationFailureReason`

```swift
public enum CADMVVerificationFailureReason: Equatable, Sendable {
    case malformedBarcode
    case notCaliforniaDMV
    case vcbMissing(required: Bool)
    case vcbBase64Invalid
    case vcbCBORUnsupported
    case unsupportedCredentialProfile
    case environmentMismatch(expected: CADMVVerificationMode)
    case protectedAAMVADataUnavailable
    case didResolutionFailed
    case signatureMismatch
    case statusUnavailable
    case revoked
    case expired
}
```

Use this field to route app behavior without logging sensitive document data. For example, `environmentMismatch` can identify UAT/test credentials being checked in production mode, while `didResolutionFailed` separates network/key lookup failures from `signatureMismatch`.

## `CADMVScanner`

`CADMVScanner` is optional. It provides:

- `CADMVScannedBarcode`, a safe wrapper around raw PDF417 payload handoff.
- `CADMVVisionKitPDF417Scanner` on iOS where VisionKit scanning is available.

The scanner target does not parse identity data or persist camera frames.

## Non-Public Internals

The following are deliberately not public API:

- Parsed AAMVA fields.
- Decoded VCB credential payloads.
- Proof values.
- DID documents.
- Debug inspection details.

SPI-only helpers exist for `CADMVVerifierSelfTest` and should not be used by application integrations.
