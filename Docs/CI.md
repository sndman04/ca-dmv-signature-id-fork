# CI Notes

Recommended commands:

```sh
swift build
swift build -c release
swift test
swift run CADMVVerifierSelfTest
```

GitHub Actions runs these commands on push and pull request in `.github/workflows/ci.yml`.

Reference SDK parity command:

```sh
PATH="/Users/dougalvey/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin:$PATH" node Tools/reference-runner.mjs
```

If a Command Line Tools-only environment cannot import XCTest, run SwiftPM with the full Xcode toolchain:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run CADMVVerifierSelfTest
```

The SwiftPM tests cover focused regression cases. The self-test contains the official valid/invalid UAT fixture parity checks and uses fixture-backed DID Web and status endpoint responses. CI must run both `swift test` and `swift run CADMVVerifierSelfTest`.

## Expected Self-Test Coverage

- Synthetic non-PII AAMVA behavior.
- Missing optional VCB.
- Required missing VCB.
- Non-California barcode.
- Scanner wrapper payload forwarding and availability reporting.
- Issue date leap-year, boundary-date, invalid-date, and future-date behavior.
- Impossible issue date fails closed when a required VCB cannot be established from a real calendar date.
- Malformed base64 VCB.
- Malformed CBOR-LD VCB.
- Current, uncompressed, legacy uncompressed, and legacy compressed CBOR-LD DMV-profile decode forms.
- Malformed AAMVA header/subfile descriptor offsets and lengths fail closed.
- Base64/Base64URL malformed length, alphabet, and padding rejection.
- Base58 malformed alphabet rejection.
- Status-list gzip output limit enforcement.
- Malformed status-list multibase/gzip corpus rejection.
- Official valid DMV UAT fixture verification.
- Official invalid DMV UAT fixture rejection.
- Tampered protected AAMVA field rejection.
- UAT fixture rejection in production mode.
- Status-required official UAT verification returns `.unavailable` on fixture-backed HTTP status failure.
- Synthetic JS-reference Bitstring Status List `ecdsa-rdfc-2019` verification.
- Verified revoked status-list bit maps to `.revoked`.
- Verified clear status-list bit maps to `.verified`.
- Tampered status-list `encodedList` fails proof verification.
- Fixture-backed DMV DID Web key resolution, mode mismatch rejection, non-2xx rejection, and assertion-method authorization rejection.
