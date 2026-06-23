# Threat Model

## Assets

- Raw PDF417 barcode data.
- Parsed AAMVA fields.
- Decoded VCB credential metadata.
- Verification status returned to the integrating app.
- DID documents and status-list credentials fetched from DMV hosts.

## Primary Risks

- Accidental logging or persistence of PII.
- Treating malformed or unsupported VCB data as valid.
- Fetching attacker-controlled URLs from untrusted credential data.
- Accepting credentials from the wrong DMV environment.
- Accepting a signature over tampered AAMVA barcode fields.
- Treating unavailable online status infrastructure as verified.
- Drift from the official DMV JavaScript SDK behavior.

## Controls

- Public results are privacy-minimized.
- The package does not log barcode data or parsed identity fields.
- Unsupported CBOR, CBOR-LD registry values, issuers, cryptosuites, proof types, and DID methods fail closed.
- DID Web resolution uses explicit production/UAT DMV URLs, not arbitrary credential-provided URLs.
- Status-list fetches use explicit DMV API host allowlists and suppress redirects.
- AAMVA protected-component hashing is compared against the official SDK fixture output.
- Signature verification uses the DID-resolved DMV P-256 Multikey and the DMV optical-data hash as extra information.

## Current Residual Risk

- Live DMV status infrastructure can still be unavailable or return unsupported data. When that happens, status-required verification returns `.unavailable`.
- The native `ecdsa-xi-2023` implementation is intentionally scoped to the DMV VCB profile covered by the official UAT fixtures, not a general JSON-LD/RDF engine.
- The native `ecdsa-rdfc-2019` status-list implementation is intentionally scoped to the supported DMV VC v2 Bitstring Status List profile, not arbitrary JSON-LD credentials.
- The iOS scanner wrapper has not been physically device-tested.
