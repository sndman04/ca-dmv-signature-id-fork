# DMV Technical Guide Review

Reviewed source:

- `https://www.dmv.ca.gov/portal/file/verifying-digital-signatures-on-california-dlid-documents-pdf/`
- Document label: `REV DEC25`

## Confirmed Implementation Points

- California DL/ID digital signature payloads are in the `ZCE` field of the `ZC` subfile.
- The payload is base64 encoded CBOR-LD.
- The example CBOR-LD payload uses registry entry `31000000`.
- The decoded credential uses:
  - `https://www.w3.org/ns/credentials/v2`
  - `https://w3id.org/vc-barcodes/v1`
  - `OpticalBarcodeCredential`
  - `TerseBitstringStatusListEntry`
  - `ecdsa-xi-2023`
  - `did:web:uat-credentials.dmv.ca.gov#vm-vcb-1`
- The signature covers the credential and selected PDF417/AAMVA data.
- For the guide's example, `protectedComponentIndex` is `u_3Bg`.
- The canonicalized AAMVA data is sorted `field + value` lines joined with `\n` and a trailing newline.
- The optical data path is a double hash: canonicalized AAMVA bytes are hashed, and that hash is used as extra information that is hashed again during `ecdsa-xi-2023` verify-data construction.
- Production verifiers must enforce the expected production DMV DID:
  - `did:web:credentials.dmv.ca.gov`
- Terse status-list conversion uses:
  - `listIndex = floor(terseStatusListIndex / 67108864)`
  - `statusListIndex = terseStatusListIndex % 67108864`
  - status purpose `revocation`

## Verified Against Current Swift Implementation

- `CADMVVerifierSelfTest` extracts the official UAT fixtures from the reference SDK.
- The valid UAT fixture verifies as `.verified` with status checking disabled.
- The invalid UAT fixture fails signature verification.
- The Swift canonical AAMVA hash matches the JS SDK for both official UAT fixtures.
- The Swift verify-data bytes match the JS SDK for the valid UAT fixture.
- The status-list URL for the valid UAT fixture is:
  - `https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists/revocation/57`
- The status-list bit index for the valid UAT fixture is:
  - `41319687`

## Current Divergence / External State

The technical guide describes Appendix B as a revoked example. The captured JavaScript SDK currently reports the Appendix B fixture as an invalid signature, and the live UAT status URL redirects to `status.uat-credentials.dmv.ca.gov` before returning 404. Until DMV status infrastructure and redistributable status-list fixtures are available, this Swift package returns `.unavailable` whenever status checking is required.
