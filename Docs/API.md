# Public API

The public API is intentionally small and privacy-minimized.

This package verifies the supported California DMV DL/ID VCB profile. It is not a general JSON-LD/Data Integrity verifier. The current profile support accepts DMV VCB `protectedComponentIndex` values encoded as `u` plus a 24-bit bitmap, and the reference canonicalizer's equivalent numeric 24-bit form; credentials outside that profile fail closed as unsupported.

## `CADMVVerifier`

Endpoint-style summary:

- Call: `CADMVVerifier.verify(rawPDF417:options:)`
- Input payload: one scanner-produced PDF417 string plus optional verification controls.
- Output payload: one `CADMVVerificationResult`.
- Throws: never. All verifier-owned failures are returned as result values.
- Network: DID Web key lookup always runs for signed VCB verification. Status-list network checks run only when `options.checkStatus == true`.
- Privacy: the API does not log, persist, or return parsed identity data, raw barcode data, decoded credentials, proof values, DID documents, or status-list contents.

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

Expected request shape:

| Field | Required | Meaning |
| --- | --- | --- |
| `rawPDF417` | Yes | Full raw PDF417 payload from the scanner. This may contain PII and must be treated as sensitive. |
| `options.requireVCB` | No | Whether app policy requires VCB data on every California DL/ID, including older documents. |
| `options.checkStatus` | No | Whether to perform online revocation/status-list verification after signature verification. |
| `options.mode` | No | DMV environment to accept: `.production` or `.uat`. |
| `options.networkTimeoutSeconds` | No | Timeout for DID/status network requests. Invalid values normalize to the default. |

Expected response shape:

| Field | Meaning |
| --- | --- |
| `status` | High-level verification outcome. Treat only `.verified` as verified. |
| `message` | Privacy-safe user/developer message for verifier-created results. |
| `failureReason` | Privacy-safe diagnostic enum for non-verified verifier results. `nil` for `.verified`. |

Example:

```swift
let result = await CADMVVerifier.verify(
    rawPDF417: scannerPayload,
    options: CADMVVerificationOptions(
        requireVCB: false,
        checkStatus: true,
        mode: .production,
        networkTimeoutSeconds: 10
    )
)
```

## `CADMVVerificationOptions`

```swift
public struct CADMVVerificationOptions: Sendable {
    public var requireVCB: Bool
    public var checkStatus: Bool
    public var mode: CADMVVerificationMode
    public var networkTimeoutSeconds: Double

    public init(
        requireVCB: Bool = false,
        checkStatus: Bool = false,
        mode: CADMVVerificationMode = .production,
        networkTimeoutSeconds: Double = 10
    )

    public static let `default`: CADMVVerificationOptions
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

Unsupported status-list credential shapes fail closed. Newly added signed fields whose property names are safe absolute `http` or `https` IRIs are included in status-list document/proof canonicalization when their values can be represented by the supported JSON-LD/RDF path. Compact unknown property names and unsafe IRIs still make status unavailable rather than being ignored. Development-only SPI diagnostics can identify unknown status-list key names for maintainers, but public results intentionally remain privacy-minimized.

For VCB credentials, status-list credentials, and Data Integrity proofs, standards-valid extension fields whose property names are safe absolute `http` or `https` IRIs are included in canonicalization when their values can be represented by the supported JSON-LD/RDF path. The current JS-parity-covered extension subset includes strings, JSON integers and doubles, booleans, arrays, null omission, `@set`, `@list`, `@value` with safe `@type`, `@language`, `@direction`, or `@type: "@json"`, absolute-IRI and explicit blank-node `@id` node references, nested absolute-IRI node objects, node-object `@type`, `@reverse`, `@graph`, `@included`, `@nest`, and string `@index` metadata ignored by RDF output. Compact unknown property names and unsafe IRIs fail closed as unsupported credential profiles rather than being ignored.

Numeric extension values must be finite JSON numbers. Non-finite numeric values are rejected at the JSON-LD value boundary, and finite values are normalized with bounded coefficient and exponent sizes. Values outside those bounds fail closed rather than being expanded into large RDF lexical forms.

When a verified credential includes credential `validUntil` data, the verifier returns `.expired` after the signature verifies and after any required revocation check completes as not revoked. Proof `expires` is signed proof metadata and is canonicalized and signature-protected, but the JS reference verifier does not use it as a credential-expiration source. If status checking is required but unavailable, `.unavailable` takes precedence over `.expired`; if the status list marks the credential revoked, `.revoked` takes precedence.

DID Web key lookup is required for signature verification regardless of `checkStatus`. If the selected DMV DID host cannot be resolved or reached, the request times out, the response is not a direct 2xx HTTP response, or the DID document is malformed, verification returns `.failed` with `failureReason == .didResolutionFailed`.

## `CADMVVerificationResult`

```swift
public struct CADMVVerificationResult: Equatable, Sendable {
    public let status: CADMVVerificationStatus
    public let message: String?
    public let failureReason: CADMVVerificationFailureReason?

    public init(
        status: CADMVVerificationStatus,
        message: String? = nil,
        failureReason: CADMVVerificationFailureReason? = nil
    )
}
```

`CADMVVerifier.verify(rawPDF417:options:)` returns a `CADMVVerificationResult`
and does not throw. Verifier-created results include a privacy-safe `message`
for every status. The public initializer permits `message == nil` for app-owned
results or tests.

`failureReason` is a privacy-safe diagnostic for non-verified results. It never
contains raw barcode data, decoded AAMVA fields, proof values, DID documents, or
status-list contents. It is `nil` for `.verified` results from the verifier.

Verifier-created messages:

| Status | Message |
| --- | --- |
| `.verified` | `DMV digital-signature verification passed.` |
| `.failed` | `DMV digital-signature verification failed.` |
| `.notPresent` | `California DMV digital signature is not present.` |
| `.revoked` | `This DMV digital credential has been revoked.` |
| `.expired` | `This DMV digital credential is expired.` |
| `.unavailable` | `DMV digital-signature verification is temporarily unavailable.` |

## `CADMVVerificationMode`

```swift
public enum CADMVVerificationMode: Equatable, Sendable {
    case production
    case uat
}
```

`CADMVVerificationMode` is sent through `CADMVVerificationOptions.mode`.
It controls the accepted DMV issuer, DID Web host, verification-method key, and
status-list host. It is also returned inside
`CADMVVerificationFailureReason.environmentMismatch(expected:)` when a
credential is valid only for the other environment.

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
- `.expired`: signature verification passed and required status checking, if enabled, completed as not revoked, but credential `validUntil` is at or before the verification time.

Status/failure relationship:

| Status | Typical `failureReason` | App meaning |
| --- | --- | --- |
| `.verified` | `nil` | The supported DMV signature checks passed. |
| `.notPresent` | `.notCaliforniaDMV`, `.vcbMissing(required: false)` | No applicable California DMV digital signature was available. |
| `.failed` | Malformed, unsupported, mismatch, environment, DID, or signature failure reasons | Verification failed closed. Do not treat as verified. |
| `.unavailable` | `.statusUnavailable` | Signature verification passed, but required status infrastructure could not be verified. Retry or handle separately from verified. |
| `.revoked` | `.revoked` | Signature and status-list proof verified, and the status bit is revoked. |
| `.expired` | `.expired` | Signature passed and the credential `validUntil` value is expired. |

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

Failure definitions:

| Failure reason | Returned status | Definition |
| --- | --- | --- |
| `.malformedBarcode` | `.failed` | The input could not be parsed as an AAMVA PDF417 payload with a usable header, subfile table, field separators, and fields. This can also happen when a barcode decoder returns display text instead of the raw scanner payload with separator bytes preserved. |
| `.notCaliforniaDMV` | `.notPresent` | The payload parsed, but it is not a California DMV DL/ID document accepted by this verifier. The issuer/state/subfile checks did not match the supported CA DMV profile. |
| `.vcbMissing(required: false)` | `.notPresent` | The document is California DMV, but no VCB field is present and VCB data was not required for this document/app policy. |
| `.vcbMissing(required: true)` | `.failed` | A VCB field is required because `requireVCB == true` or the document issue date is on/after the DMV requirement date, but no VCB field was present. |
| `.vcbBase64Invalid` | `.failed` | The VCB field was present but was not valid Base64URL/Base64 payload data. |
| `.vcbCBORUnsupported` | `.failed` | The decoded VCB bytes were malformed CBOR/CBOR-LD or used unsupported encodings, duplicate keys, unsafe aliases, oversized declarations, or unknown compressed term IDs. |
| `.unsupportedCredentialProfile` | `.failed` | The decoded credential, proof, JSON-LD shape, extension fields, context set, status-list shape, expiration value, or canonicalization input is outside the supported DMV profile and parity-tested safe extension subset. |
| `.environmentMismatch(expected:)` | `.failed` | The credential belongs to the other DMV environment. For example, a UAT credential was checked in `.production` mode, or a production credential was checked in `.uat` mode. The associated value tells the environment expected by that credential. |
| `.protectedAAMVADataUnavailable` | `.failed` | The credential requested protected AAMVA components that could not be selected and hashed from the parsed barcode data. |
| `.didResolutionFailed` | `.failed` | The required DID Web verification key could not be resolved or validated. Causes include offline/DNS failure, timeout, non-direct/non-2xx HTTP response, malformed DID document, unsupported key material, or missing authorized assertion method. |
| `.signatureMismatch` | `.failed` | The VCB signature did not verify against the decoded credential, protected AAMVA hash, canonicalized proof/document data, and resolved verification key, or signature bytes were malformed/unsupported. |
| `.statusUnavailable` | `.unavailable` | `checkStatus == true`, the VCB signature passed, but the DMV status-list check could not complete as cryptographically verified not-revoked. Causes include status URL policy failure, network/HTTP failure, malformed or unsupported status-list credential, status-list DID/key failure, status-list proof failure, or invalid encoded bitstring data. |
| `.revoked` | `.revoked` | `checkStatus == true`, the status-list credential proof verified, and the credential's status bit is set to revoked. |
| `.expired` | `.expired` | The VCB signature passed and the credential `validUntil` value is at or before verification time. If status checking is required and unavailable, `.statusUnavailable` takes precedence; if revoked, `.revoked` takes precedence. |

The failure enum is intentionally not a raw exception surface. Multiple low-level parser, network, cryptographic, and JSON-LD errors map to the closest privacy-safe public reason.

## `CADMVScanner`

`CADMVScanner` is optional. It provides an app-facing camera boundary around raw
PDF417 payload capture. It does not parse identity data or persist camera
frames.

Endpoint-style summary:

- Call: `CADMVScannedBarcode.verify(options:)`
- Input payload: an existing `CADMVScannedBarcode` containing one raw PDF417 string.
- Output payload: the same `CADMVVerificationResult` returned by `CADMVVerifier.verify(rawPDF417:options:)`.
- Throws: never.
- Privacy: forwards the raw payload in memory without parsing public PII.

```swift
public struct CADMVScannedBarcode: Equatable, Sendable {
    public let rawPDF417: String

    public init(rawPDF417: String)

    public func verify(
        options: CADMVVerificationOptions = .default
    ) async -> CADMVVerificationResult
}
```

`CADMVScannedBarcode.rawPDF417` is the full scanner-provided PDF417 string. It
is the same sensitive value accepted by `CADMVVerifier.verify(rawPDF417:)`.
`CADMVScannedBarcode.verify(options:)` sends `rawPDF417` and `options` directly
to `CADMVVerifier.verify(rawPDF417:options:)` and returns that verifier result.

Expected request shape:

| Field | Required | Meaning |
| --- | --- | --- |
| `rawPDF417` | Yes | Full scanner-produced PDF417 payload. Preserve separator bytes. |
| `options` | No | Same options accepted by `CADMVVerifier.verify(rawPDF417:options:)`. |

Expected response shape:

| Field | Meaning |
| --- | --- |
| `CADMVVerificationResult.status` | Same status contract as the core verifier. |
| `CADMVVerificationResult.message` | Same message contract as the core verifier. |
| `CADMVVerificationResult.failureReason` | Same privacy-safe failure contract as the core verifier. |

```swift
public enum CADMVScannerAvailability: Equatable, Sendable {
    case available
    case unavailable(String)
}

public enum CADMVScanner {
    public static var availability: CADMVScannerAvailability
}
```

`CADMVScanner.availability` reports whether package-provided native camera
scanning is available. On supported iOS devices it can return `.available`; on
unsupported platforms, older iOS versions, unavailable camera hardware, or when
VisionKit reports scanning unavailable, it returns `.unavailable(String)`.

Availability response definitions:

| Response | Meaning |
| --- | --- |
| `.available` | The optional scanner target can present VisionKit PDF417 scanning on this device. |
| `.unavailable(String)` | Native camera scanning is not available. The associated string is a privacy-safe reason suitable for developer diagnostics or fallback UI. Current reasons include unsupported platform/device or unavailable VisionKit scanning. |

On iOS 16 and later where VisionKit and UIKit are available, the scanner target
also exposes:

```swift
@available(iOS 16.0, *)
@MainActor
public final class CADMVVisionKitPDF417Scanner: NSObject {
    public typealias ScanHandler = @MainActor (CADMVScannedBarcode) -> Void

    public init(onScan: @escaping ScanHandler)

    public var viewController: UIViewController

    public func startScanning() throws
    public func stopScanning()
}
```

The `onScan` handler receives a `CADMVScannedBarcode` when VisionKit recognizes
a non-empty PDF417 payload. `viewController` is the underlying VisionKit scanner
view controller for app presentation. `startScanning()` forwards VisionKit
startup errors to the app; `stopScanning()` stops active scanning.

VisionKit scanner request/response contract:

| API | Input | Response | Errors |
| --- | --- | --- | --- |
| `init(onScan:)` | Closure receiving `CADMVScannedBarcode` | Scanner wrapper instance | None from the initializer. |
| `viewController` | None | `UIViewController` to present | None. |
| `startScanning()` | None | Starts VisionKit scanning | Throws VisionKit startup errors, such as unavailable camera permission/hardware/session conditions. These are not `CADMVVerificationFailureReason` values because no barcode verification has happened yet. |
| `stopScanning()` | None | Stops active scanning | Does not throw. |
| `onScan` callback | VisionKit-recognized non-empty PDF417 payload | `CADMVScannedBarcode` preserving the payload string | Empty/non-PDF417 recognized items are ignored. |

Scanner errors are separate from verifier results. A scanner startup error means capture failed; a `CADMVVerificationResult` means capture produced a payload and verification ran.

## Non-Public Internals

The following are deliberately not public API:

- Parsed AAMVA fields.
- Decoded VCB credential payloads.
- Proof values.
- DID documents.
- Debug inspection details, including SPI-only status-list profile drift diagnostics.

SPI-only helpers exist for `CADMVVerifierSelfTest` and should not be used by application integrations.
