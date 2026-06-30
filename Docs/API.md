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
whitespace and newline trimming is tolerated. Separator bytes such as `\r`,
`\u{001d}`, `\u{001e}`, and `\u{001f}` should otherwise be preserved.

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

`networkTimeoutSeconds` is applied to DMV DID Web and status-list requests. Non-finite and non-positive values such as `NaN`, infinity, `0`, or negative numbers are treated as the default `10` seconds so integrations do not accidentally disable or destabilize network timeouts.

`mode` selects which DMV environment is accepted. `.production` accepts only
production DMV issuer, DID, key, and status hosts. `.uat` accepts only DMV
UAT/test credentials. A credential from the other environment fails with
`environmentMismatch(expected:)`.

`requireVCB = false` still requires signed VCB data for California documents
issued on or after the DMV requirement date. It allows older California
documents to return `.notPresent` when no VCB field exists. Set
`requireVCB = true` only when app policy requires signed DMV data on every
California DL/ID scan, including older documents.

`checkStatus = true` performs online revocation checking. If the DMV status endpoint is unavailable, redirects outside the allowed fetch policy, returns an unsupported credential shape, or the status-list credential proof cannot be verified, the result is `.unavailable`. Application integrations should treat only `.verified` as verified.

Unsupported status-list credential shapes fail closed. This includes newly added signed fields that the native Swift canonicalizer does not yet know how to include in the signature verification input. Development-only SPI diagnostics can identify unknown status-list key names for maintainers, but public results intentionally remain privacy-minimized.

When a verified credential includes `validUntil` or proof `expires` data, the verifier returns `.expired` after the signature verifies and after any required revocation check completes as not revoked. If status checking is required but unavailable, `.unavailable` takes precedence over `.expired`; if the status list marks the credential revoked, `.revoked` takes precedence.

DID Web key lookup is required for signature verification regardless of `checkStatus`. If the selected DMV DID host cannot be resolved or reached, the request times out, the response is not a direct 2xx HTTP response, or the DID document is malformed, verification returns `.failed` with `failureReason == .didResolutionFailed`.

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

- `.verified`: signature verification passed for the supported DMV VCB profile, status checking either was disabled or verified the credential as not revoked, and available expiration data has not expired.
- `.failed`: malformed data, unsupported data, issuer/mode mismatch, DID/key lookup failure, invalid signature, or required VCB missing.
- `.notPresent`: non-California or pre-requirement-date document without VCB.
- `.unavailable`: required status checking cannot complete.
- `.revoked`: a cryptographically verified status-list credential marks the revocation bit as set.
- `.expired`: signature verification passed and required status checking, if enabled, completed as not revoked, but credential expiration data is at or before the verification time.

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

Use this field to route app behavior without logging sensitive document data. For example, `environmentMismatch` can identify UAT/test credentials being checked in production mode, while `didResolutionFailed` separates DMV DID host resolution, timeout, response, and DID-document parsing failures from `signatureMismatch`.

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
- Debug inspection details, including SPI-only status-list profile drift diagnostics.

SPI-only helpers exist for `CADMVVerifierSelfTest` and should not be used by application integrations.
