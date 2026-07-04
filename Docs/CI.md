# CI Notes

Recommended commands:

```sh
swift build
swift build -c release
Tools/swift-test.sh
swift run CADMVVerifierSelfTest
Tools/parity-status.sh
Tools/reference-oracle-smoke.sh
Tools/status-list-parity.mjs
node Tools/status-list-extension-matrix-parity.mjs
node Tools/canonicalization-engine-differential.mjs
node Tools/jsonld-extension-matrix-parity.mjs
Tools/signature-policy-characterization.mjs
Tools/generated-signature-parity.mjs
node Tools/mutation-parity.mjs
```

Before a release that claims full JavaScript SDK replacement parity, also run:

```sh
Tools/replacement-readiness.sh
```

This gate is intentionally stricter than the normal push gates. It fails while public verification still defaults to the supported-profile canonicalization engine or while release-blocking replacement caveats remain in docs/generated reports.

GitHub Actions runs the Swift gates, parity status check, and `Tools/reference-oracle-smoke.sh` on push and pull request in `.github/workflows/ci.yml`. The smoke wrapper runs the JS reference parity tools when Node and the reference SDK dependencies are available.

Reference SDK parity command:

```sh
PATH="/Users/dougalvey/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin:$PATH" node Tools/reference-runner.mjs
```

`Tools/swift-test.sh` automatically points SwiftPM at the full Xcode toolchain when `xcode-select` is using Command Line Tools, because Command Line Tools may not expose XCTest. The equivalent manual commands are:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run CADMVVerifierSelfTest
```

The SwiftPM tests cover focused regression cases. The self-test contains the official valid/invalid UAT fixture parity checks and uses fixture-backed DID Web and status endpoint responses. CI must run both `Tools/swift-test.sh` and `swift run CADMVVerifierSelfTest`.

`Tools/parity-status.sh` reports known JS/Swift parity gaps from `Docs/PARITY_STATUS.md` separately from Swift unit-test failures. During Phase 0 it is informational because the migration plan intentionally records known blocking parity work before the JS oracle harness is complete.

`Tools/reference-oracle-smoke.sh` runs the JavaScript reference oracle when Node and the reference SDK dependencies are available. If either is missing, it prints an explicit skip message instead of silently passing as though JS parity was checked.

The reference oracle supports two modes:

```sh
# Built-in official fixture summary.
node Tools/reference-runner.mjs

# Privacy-minimized stdin oracle for a scanner payload kept in process memory.
node Tools/reference-runner.mjs --stdin --mode=prod

# Swift/JS parity comparison for committed official fixtures.
node Tools/parity-compare.mjs

# Swift/JS status-list verify-data parity for synthetic status-list fixtures.
node Tools/status-list-parity.mjs

# Shape-by-shape status-list extension canonical N-Quads and verify-data parity.
node Tools/status-list-extension-matrix-parity.mjs

# Replacement canonicalization engine differential across supported profiles.
node Tools/canonicalization-engine-differential.mjs

# JS reference Data Integrity signature encoding and high-S policy.
node Tools/signature-policy-characterization.mjs

# Generated end-to-end VCB signature parity fixtures.
node Tools/generated-signature-parity.mjs

# Deterministic malformed VCB mutation parity fixtures.
node Tools/mutation-parity.mjs

# Shape-by-shape generic JSON-LD extension canonical N-Quads parity.
node Tools/jsonld-extension-matrix-parity.mjs

# JSON-LD edge behavior classification against JS safe-mode canonicalization.
node Tools/jsonld-behavior-characterization.mjs
```

The stdin mode emits JSON with the selected SDK baseline, mode, high-level outcome, first failure stage, VCB byte count, credential profile class, AAMVA optical hash, and VCB verify-data hex when a VCB can be decoded. It must not be used to log raw PDF417 payloads or decoded identity fields.

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
- Oversized CBOR byte/text length and array/map count declarations fail closed before allocation.
- Unsupported CBOR indefinite-length, simple-value, float, break-code, negative-overflow, and trailing-byte encodings fail closed.
- Current, uncompressed, legacy uncompressed, and legacy compressed CBOR-LD DMV-profile decode forms.
- Malformed AAMVA header/subfile descriptor offsets and lengths fail closed.
- Base64/Base64URL malformed length, alphabet, and padding rejection.
- Base58 malformed alphabet rejection.
- Data Integrity proofValue `z` base58btc and `u` base64url acceptance, text proofValue preservation before signature extraction, malformed/unsupported raw-signature rejection, and P-256 high-S counterpart behavior against the JS reference.
- Generic JSON-LD extension number parsing rejects non-finite values, and number normalization is bounded so oversized coefficients and exponents fail closed before large allocation.
- Production JSON-LD canonicalization defaults route through one selector so the final engine replacement is not scattered across verifier helpers.
- Generated end-to-end VCB signatures covering valid `z`, valid `u`, status-bearing credentials, validity dates, expired valid signatures, tampered proof signature, and tampered protected AAMVA field parity against the JS reference.
- Status-list gzip output limit enforcement.
- Malformed status-list multibase/gzip corpus rejection.
- Official valid DMV UAT fixture verification.
- Official invalid DMV UAT fixture rejection.
- Tampered protected AAMVA field rejection.
- UAT fixture rejection in production mode.
- Status-required official UAT verification returns `.unavailable` on fixture-backed HTTP status failure.
- Status-list checking returns `.unavailable` for status transport failures, redirect/404/500 responses, malformed status-list credential JSON, malformed DID documents, and unsupported DID keys during status-list proof-key resolution.
- Synthetic JS-reference Bitstring Status List `ecdsa-rdfc-2019` verification.
- Verified revoked status-list bit maps to `.revoked`.
- Verified clear status-list bit maps to `.verified`.
- Tampered status-list `encodedList` fails proof verification.
- Fixture-backed DMV DID Web key resolution, mode mismatch rejection, non-2xx rejection, and assertion-method authorization rejection.
