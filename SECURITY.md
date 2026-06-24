# Security Policy

This project handles verification data derived from government identity
documents. Raw PDF417 barcode data and parsed AAMVA fields can contain
personally identifiable information.

## Reporting Vulnerabilities

Please report security issues privately through GitHub Security Advisories when
available. If private advisories are not available for this repository, open a
minimal public issue that describes the affected behavior without including
real barcode payloads, decoded credentials, identity-document images, keys, or
personal data.

Do not post:

- Raw PDF417 barcode data from a real person.
- Photos or screenshots of driver licenses or identification cards.
- Parsed AAMVA fields from a real person.
- Decoded credential payloads, proof values, DID documents, or status-list
  contents that came from a real scan.

Synthetic fixtures, DMV-published samples whose redistribution is permitted,
and short redacted byte-level examples are acceptable.

## Supported Versions

This repository is under active implementation. Security fixes are expected to
land on `main` until a tagged release policy exists.

## Integration Expectations

Applications using this package should treat only `.verified` as verified,
preserve `.unavailable` as a distinct result, and avoid logging or persisting
raw barcode data unless the application has its own legal basis and security
controls.
