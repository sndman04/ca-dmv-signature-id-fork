# Dependency and License Audit

## Swift Package

Swift package dependencies:

- `swift-crypto` 4.5.0 from Apple, Apache-2.0.
- `swift-asn1` 1.7.1 from Apple, Apache-2.0, resolved transitively by `swift-crypto`.

`swift-crypto` is used for CryptoKit-compatible APIs across Swift platforms. On Apple platforms it re-exports CryptoKit-backed behavior; on non-Apple platforms it provides a BoringSSL-backed implementation.

Apple frameworks used:

- `Foundation`
- `FoundationNetworking` where required by non-Darwin Swift toolchains
- `VisionKit` in the optional iOS scanner target
- `UIKit` in the optional iOS scanner target
- `zlib`, linked as a system library for gzip decoding of Bitstring Status List `encodedList` values

## Reference SDK

The official JavaScript SDK is kept under `References/cadmv-dlid-verifier-sdk/` for parity and attribution tracking.

- Repository: `https://github.com/stateofca/cadmv-dlid-verifier-sdk`
- Captured commit: `03c5485513ff6f2de6b46950a159b8f2cd427859`
- License: BSD-3-Clause

The reference SDK imports `@digitalbazaar/did-io` but does not declare it in `package.json` at the captured commit. The local reference checkout includes a harness-only dependency patch adding `@digitalbazaar/did-io@2.2.0` so upstream tests can run.

## Attribution Requirements

Redistributions must retain BSD-3-Clause notices from the reference SDK where behavior or source material is derived.

The project must not imply endorsement by California DMV, Digital Bazaar, Inc., or reference SDK contributors.

See `NOTICE` for current attribution text.
