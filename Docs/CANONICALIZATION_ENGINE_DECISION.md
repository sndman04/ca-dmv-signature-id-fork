# Canonicalization Engine Decision

Decision date: 2026-07-03

## Decision

The default verifier will remain native Swift and will not add a Node, C, Rust, or Java canonicalization bridge during the current Phase 4 hardening work.

The implementation path is:

1. Keep the public verifier dependency surface small: Swift, `swift-crypto`, Foundation, and the existing system `zlib` link.
2. Continue replacing raw handbuilt N-Quads with typed RDF terms, derived blank-node labels, and explicit JSON-LD-to-RDF expansion boundaries.
3. Use the official JavaScript SDK only as a development and CI oracle.
4. Adopt an external canonicalization dependency only after it can satisfy the acceptance criteria below.

This is not a declaration that the current native profile implementation is the final one-to-one replacement. The final replacement still needs either a complete native JSON-LD/RDF canonicalization implementation or an audited dependency that passes the parity corpus.

## Rationale

The safest path today is incremental native hardening because the verifier is privacy-sensitive, runs in client apps, and has a narrow DMV credential profile. Adding a runtime bridge would expand the attack surface, increase platform risk, and make iOS/watchOS/visionOS distribution harder before the bridge proves it can cover the exact DMV JavaScript behavior.

Current evidence:

- The W3C RDFC-1.0 test suite defines exact text comparisons for canonical N-Quads and negative tests for excessive n-degree hashing work.
- The W3C implementation report lists conforming implementations in several ecosystems, but not a mature, widely adopted Swift JSON-LD 1.1 plus RDFC stack.
- A pure-Swift RDFC package exists, but it is new and only covers RDF Dataset Canonicalization, not the full JSON-LD 1.1 expansion and RDF transformation path needed to replace the JavaScript verifier.
- Rust and Java RDFC implementations exist, but adding them would require a bridge and platform-specific packaging work.

Reference links:

- W3C RDFC-1.0 specification: `https://www.w3.org/TR/rdf-canon/`
- W3C RDFC test suite: `https://w3c.github.io/rdf-canon/tests/`
- W3C implementation report: `https://w3c.github.io/rdf-canon/reports/`
- Swift package candidate observed during review: `https://swiftpackageindex.com/Kingpin-Apps/swift-rdf-canonize`
- Rust package candidate observed during review: `https://crates.io/crates/rdf-canon`
- Java package candidate observed during review: `https://github.com/filip26/titanium-rdf-canon`

## Acceptance Criteria For Any External Engine

An external engine can replace the native profile implementation only if it satisfies all of these:

- Produces byte-identical canonical N-Quads to the official JavaScript SDK for committed official fixtures.
- Produces byte-identical verify-data to the official JavaScript SDK for committed official and generated synthetic fixtures.
- Preserves JS-accepted text-encoded unknown signed fields through canonicalization.
- Rejects unknown compressed numeric CBOR-LD term ids to match JS decode behavior.
- Passes the W3C RDFC-1.0 positive and negative tests relevant to the supported RDF dataset surface.
- Has a license compatible with this package and redistributable app binaries.
- Works on the package target platforms or is cleanly unavailable without weakening default verification:
  - iOS 16+
  - macOS 13+
  - tvOS 16+
  - watchOS 9+
  - visionOS 1+
- Does not require runtime network access for JSON-LD contexts.
- Supports pinned context loading for DMV, VC, and security contexts.
- Has bounded resource behavior or an enforceable recursion/work budget for difficult blank-node graphs.

## Bridge-Specific Requirements

If a C, C++, Rust, Java, or JavaScript bridge is proposed later, the implementation must include:

- Memory ownership rules for every value crossing the ABI boundary.
- Fuzz or malformed-input tests for the bridge wrapper.
- Thread-safety and Swift concurrency documentation.
- Build and distribution instructions for every supported Apple platform.
- Static/dynamic linking implications.
- Minimum OS and architecture matrix.
- Failure mapping from bridge errors to privacy-minimized public verifier results.
- A fallback policy for platforms where the bridge cannot be built.

## Current Native Guardrails

Until the final engine lands, the native verifier must continue to fail closed when accepting an input would require canonicalizing unsupported signed data.

Current guardrails:

- Unknown signed VCB fields fail closed.
- Unknown status-list signed fields fail closed or return `.unavailable`.
- VCB document canonicalization passes through a supported-context JSON-LD-to-RDF conversion boundary before RDF Dataset Canonicalization; unsupported contexts and unknown signed terms fail closed there.
- Official UAT VCB proof canonical N-Quads, document canonical N-Quads, AAMVA optical hash, and verify-data are compared against the JavaScript SDK.
- Synthetic status-list verify-data is compared against the JavaScript SDK.
- RDFC n-degree canonicalization has an explicit recursion/work budget.

## Revisit Triggers

Revisit this decision when one of these becomes true:

- A Swift JSON-LD 1.1 plus RDFC implementation matures enough to pass the parity corpus.
- A bridge candidate demonstrably passes the full corpus and satisfies the bridge requirements above.
- DMV expands the credential profile with signed fields that make the narrow native profile no longer practical.
- The W3C RDFC conformance ecosystem changes enough to justify adopting a maintained dependency.
