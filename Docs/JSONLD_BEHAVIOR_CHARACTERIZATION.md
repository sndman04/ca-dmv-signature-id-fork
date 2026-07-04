# JSON-LD Behavior Characterization

`Tools/jsonld-behavior-characterization.mjs` records the current JS SDK and Swift behavior for JSON-LD 1.1 shapes around the supported DMV extension surface.

The gate is intentionally classification-based:

- `implemented`: JS accepts the case, Swift accepts it, and canonical N-Quads are byte-identical.
- `swiftFailClosed`: JS accepts the case, but Swift rejects it by policy until the final standards-grade/native-library-backed engine is default.
- `bothReject`: JS safe-mode canonicalization and Swift both reject the case.

## Current Classifications

| Case | Classification | Meaning |
| --- | --- | --- |
| `implemented-absolute-id-node` | `implemented` | Safe absolute `@id` node references are part of the supported extension subset. |
| `implemented-nested-graph` | `implemented` | Generic named graph handling is covered by existing parity fixtures. |
| `implemented-json-literal` | `implemented` | `@type: "@json"` value objects are covered by existing parity fixtures. |
| `fail-closed-relative-id-node` | `bothReject` | Relative `@id` values are rejected by JS safe mode and Swift. |
| `fail-closed-blank-node-id` | `swiftFailClosed` | JS accepts explicit blank-node identifiers, but Swift rejects them because the DMV profile does not need explicit blank-node labels and the current supported-profile path is not a full JSON-LD node identifier processor. |
| `fail-closed-nested-context` | `bothReject` | This nested context shape is rejected by JS safe mode and Swift. |
| `fail-closed-compact-property` | `bothReject` | Compact unknown properties do not expand through the pinned context set and are rejected. |
| `fail-closed-reverse-literal` | `bothReject` | Reverse properties with literal values are invalid for the characterized shape. |
| `fail-closed-type-language-conflict` | `bothReject` | JSON-LD value objects cannot combine `@type` with `@language` or `@direction`. |
| `fail-closed-invalid-direction` | `bothReject` | JSON-LD accepts only `ltr` and `rtl` direction values. |
| `fail-closed-typed-json-object-absolute-iri` | `bothReject` | Structured JSON values are accepted by the JS SDK only with `@type: "@json"`, not expanded `rdf:JSON` IRI spelling. |
| `fail-closed-non-string-index` | `bothReject` | Non-string `@index` metadata is rejected by JS safe mode and Swift. |

## Policy

The single current `swiftFailClosed` case is not a parity gap for the supported DMV verifier profile. It is a deliberately unsupported JSON-LD feature that remains blocked on the final standards-grade/native-library-backed engine decision. Swift must keep rejecting it rather than accepting and mishandling it.

If a future DMV credential profile requires explicit blank-node identifiers or broader nested context processing, that profile must be implemented through the final canonicalization engine rather than by adding one-off N-Quads generation.
