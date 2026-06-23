# Public API

The public API is intentionally small and privacy-minimized.

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

`checkStatus = true` performs online revocation checking. If the DMV status endpoint is unavailable, redirects outside the allowed fetch policy, returns an unsupported credential shape, or the status-list credential proof cannot be verified, the result is `.unavailable`.

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
