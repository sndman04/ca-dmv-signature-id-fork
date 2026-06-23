# CI Notes

Recommended commands:

```sh
swift build
swift build -c release
swift run CADMVVerifierSelfTest
```

Reference SDK parity command:

```sh
PATH="/Users/dougalvey/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin:$PATH" node Tools/reference-runner.mjs
```

The current local SwiftPM toolchain does not expose Swift `Testing` or `XCTest`, so the repository uses `CADMVVerifierSelfTest` as a repeatable verification runner.

The self-test currently performs live DID Web requests to DMV UAT and production DID document URLs. If CI must run offline, add fixture-backed DID document injection before disabling network access.

## Expected Self-Test Coverage

- Synthetic non-PII AAMVA behavior.
- Missing optional VCB.
- Required missing VCB.
- Non-California barcode.
- Malformed base64 VCB.
- Malformed CBOR-LD VCB.
- Official valid DMV UAT fixture verification.
- Official invalid DMV UAT fixture rejection.
- Tampered protected AAMVA field rejection.
- UAT fixture rejection in production mode.
- Status-required official UAT verification returns `.unavailable` while the live DMV UAT status endpoint is unusable.
- Synthetic JS-reference Bitstring Status List `ecdsa-rdfc-2019` verification.
- Verified revoked status-list bit maps to `.revoked`.
- Verified clear status-list bit maps to `.verified`.
- Tampered status-list `encodedList` fails proof verification.
- DMV DID Web key resolution and mode mismatch rejection.
