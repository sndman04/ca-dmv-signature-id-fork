# CBOR-LD Registry Audit

Baseline JavaScript SDK commit:

```text
03c5485513ff6f2de6b46950a159b8f2cd427859
```

Reference source:

```text
References/cadmv-dlid-verifier-sdk/lib/index.js
```

Swift source:

```text
Sources/CADMVVerifier/DMVVCBDecoder.swift
```

## Scope

This audit covers the DMV VCB CBOR-LD registry values needed to decode the supported California DMV DL/ID credential profile. It does not claim general CBOR-LD support.

## Context Table

| Value | Meaning | Swift Status |
| --- | --- | --- |
| `1` | `https://www.w3.org/ns/credentials/v2` | Supported |
| `2` | `https://w3id.org/vc-barcodes/v1` | Supported |

## Cryptosuite Table

| Value | Meaning | Swift Status |
| --- | --- | --- |
| `1` | `ecdsa-xi-2023` | Supported |

## DMV URL Table

| Value | Meaning | Swift Status |
| --- | --- | --- |
| `1` | `did:web:credentials.dmv.ca.gov` | Supported |
| `2` | `https://api.credentials.dmv.ca.gov/status/dlid/1/status-lists` | Supported |
| `3` | `https://api.credentials.dmv.ca.gov/status/dlid/2/status-lists` | Supported |
| `4` | `https://api.credentials.dmv.ca.gov/status/dlid/3/status-lists` | Supported |
| `5...19` | `did:web:credentials.dmv.ca.gov#vm-vcb-1...15` | Supported |
| `20` | `did:web:uat-credentials.dmv.ca.gov` | Supported |
| `21` | `https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists` | Supported |
| `22...26` | `did:web:uat-credentials.dmv.ca.gov#vm-vcb-1...5` | Supported |
| `27` | `https://api.uat-credentials.dmv.ca.gov/status/dlid/2/status-lists` | Supported |
| `28` | `https://api.uat-credentials.dmv.ca.gov/status/dlid/3/status-lists` | Supported |

## Type And Term Values

| Meaning | Swift Status |
| --- | --- |
| `VerifiableCredential` | Supported |
| `OpticalBarcodeCredential` | Supported |
| `AamvaDriversLicenseScannableInformation` | Supported |
| `TerseBitstringStatusListEntry` | Supported |
| `DataIntegrityProof` | Supported |
| `assertionMethod` | Supported |
| `proofValue` multibase `z` base58btc and `u` base64url | Supported |
| `protectedComponentIndex` as multibase bytes or reference numeric form | Supported |

## Model Preservation Policy

The current Swift decoder preserves every field currently used by the supported DMV credential shape:

- `@context`
- `type`
- `issuer`
- `validFrom`
- `validUntil`
- `credentialSubject.type`
- `credentialSubject.protectedComponentIndex`
- `credentialStatus.type`
- `credentialStatus.terseStatusListBaseUrl`
- `credentialStatus.terseStatusListIndex`
- `proof.type`
- `proof.created`
- `proof.expires`
- `proof.cryptosuite`
- `proof.proofPurpose`
- `proof.proofValue`
- `proof.verificationMethod`

Unknown signed fields fail closed today because the supported-profile canonicalization path only accepts terms it can feed into the JSON-LD-to-RDF boundary without dropping signature-relevant data. Phase 4 must replace this with standards-grade JSON-LD/RDF canonicalization that can include standards-valid signed fields without profile-specific converter changes.

## Unknown Field Characterization

`Tools/cborld-unknown-field-characterization.mjs` characterizes the reference JS CBOR-LD decoder with synthetic, non-PII credentials:

- Text-encoded unknown top-level credential keys decode successfully and are preserved in the JSON-LD object.
- Text-encoded unknown proof keys decode successfully and are preserved in `proof`.
- Unknown compressed numeric term ids fail during CBOR-LD decode.

Swift now preserves JS-accepted text-encoded unknown credential and proof keys in the decoded credential model and JSON-LD projections. Safe absolute-IRI extension terms can be included in RDF canonicalization generically; compact unknown terms still fail closed with an unsupported profile until the replacement canonicalization engine can feed those fields into the same RDF canonicalization path as the JS verifier. Unknown compressed numeric term ids continue to fail during CBOR-LD decode. The supported-context JSON-LD-to-RDF boundary also rejects unsupported signed terms rather than silently dropping them. Accepting and then dropping unknown signed fields would create a false-positive verification risk.

For compressed credentials, text keys that are aliases for supported compressed terms, such as `validUntil` or proof `created`, are not treated as extension fields. They fail during CBOR-LD decode so a payload cannot provide one value under the numeric compressed key and another under the text alias, which would otherwise make the later JSON-LD projection ambiguous.

## Parity Evidence

Current parity checks:

- `Tools/parity-compare.mjs` compares JS and Swift official UAT fixture summaries.
- The comparison includes final validity, first failure stage, AAMVA optical hash, VCB proof canonical N-Quads, VCB document canonical N-Quads, VCB verify-data, VCB byte length, and privacy-safe credential profile flags.
- `Tools/cborld-unknown-field-characterization.mjs` records JS CBOR-LD behavior for text-encoded unknown fields and unknown compressed numeric term ids.
- `Tools/signature-policy-characterization.mjs` records JS Data Integrity proofValue decoding for `z` base58btc and `u` base64url, permissive short/malformed `u` handling before the real signature verifier, malformed `z` handling, and P-256 high-S counterpart verification.
- `Tools/generated-signature-parity.mjs` records reference-emitted no-status compressed proof key ids, numeric epoch-second proof date values, and end-to-end generated signature parity for valid and tampered VCB signatures.
- `FixtureManifestTests` verifies Phase 2 fixture category coverage and privacy constraints.

Current known gap:

- `unknown-ignorable-cborld-values` is decoded into preserved JSON-LD state for JS-accepted text-key fields. Safe absolute-IRI extensions are canonicalized generically, but compact unknown terms still require standards-grade JSON-LD/RDF canonicalization before Swift can safely match JS acceptance of those signed fields.
