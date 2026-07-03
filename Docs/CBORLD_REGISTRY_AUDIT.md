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
| `proofValue` multibase/base58btc | Supported |
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

Unknown signed fields fail closed today because the legacy handbuilt canonicalization path would otherwise drop signature-relevant data. Phase 4 must replace this with standards-grade JSON-LD/RDF canonicalization that can include standards-valid signed fields without hand-editing N-Quads.

## Parity Evidence

Current parity checks:

- `Tools/parity-compare.mjs` compares JS and Swift official UAT fixture summaries.
- The comparison includes final validity, first failure stage, AAMVA optical hash, VCB byte length, and privacy-safe credential profile flags.
- `FixtureManifestTests` verifies Phase 2 fixture category coverage and privacy constraints.

Current known gap:

- `unknown-ignorable-cborld-values` requires official SDK characterization before Swift can decide whether to preserve and canonicalize or fail closed.
