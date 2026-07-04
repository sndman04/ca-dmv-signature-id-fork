# JSON-LD Behavior Characterization

`Tools/jsonld-behavior-characterization.mjs` records the current JS SDK and Swift behavior for JSON-LD 1.1 shapes around the supported DMV extension surface.

The gate is intentionally classification-based:

- `implemented`: JS accepts the case, Swift accepts it, and canonical N-Quads are byte-identical.
- `swiftFailClosed`: JS accepts the case, but Swift rejects it by supported DMV-profile policy.
- `bothReject`: JS safe-mode canonicalization and Swift both reject the case.

## Current Classifications

| Case | Classification | Meaning |
| --- | --- | --- |
| `implemented-absolute-id-node` | `implemented` | Safe absolute `@id` node references are part of the supported extension subset. |
| `implemented-nested-graph` | `implemented` | Generic named graph handling is covered by existing parity fixtures. |
| `implemented-json-literal` | `implemented` | `@type: "@json"` value objects are covered by existing parity fixtures. |
| `implemented-scalar-list` | `implemented` | Scalar `@list` values are canonicalized as one-item RDF lists in parity with JS. |
| `implemented-scalar-set` | `implemented` | Scalar `@set` values are canonicalized as single values in parity with JS. |
| `implemented-reverse-blank-node-subject` | `implemented` | Reverse properties can target generated blank-node subjects when their nested data is otherwise supported. |
| `implemented-included-blank-node` | `implemented` | `@included` nodes without explicit `@id` are canonicalized through RDFC blank-node labeling. |
| `implemented-nest-object` | `implemented` | `@nest` object blocks are flattened into the containing node in parity with JS. |
| `implemented-empty-list` | `implemented` | Empty `@list` values canonicalize to `rdf:nil` in parity with JS. |
| `fail-closed-blank-node-id` | `implemented` | Explicit blank-node identifiers with validated local labels are supported by the generic extension path and canonicalized through RDFC labels. |
| `fail-closed-relative-id-node` | `bothReject` | Relative `@id` values are rejected by JS safe mode and Swift. |
| `fail-closed-invalid-blank-node-id` | `bothReject` | Invalid explicit blank-node labels are rejected by JS safe mode and Swift. |
| `fail-closed-nested-context` | `bothReject` | This nested context shape is rejected by JS safe mode and Swift. |
| `fail-closed-compact-property` | `bothReject` | Compact unknown properties do not expand through the pinned context set and are rejected. |
| `fail-closed-reverse-literal` | `bothReject` | Reverse properties with literal values are invalid for the characterized shape. |
| `fail-closed-type-language-conflict` | `bothReject` | JSON-LD value objects cannot combine `@type` with `@language` or `@direction`. |
| `fail-closed-invalid-direction` | `bothReject` | JSON-LD accepts only `ltr` and `rtl` direction values. |
| `fail-closed-typed-json-object-absolute-iri` | `bothReject` | Structured JSON values are accepted by the JS SDK only with `@type: "@json"`, not expanded `rdf:JSON` IRI spelling. |
| `fail-closed-non-string-index` | `bothReject` | Non-string `@index` metadata is rejected by JS safe mode and Swift. |

## Policy

There are no current `swiftFailClosed` cases in this characterization matrix. New JS-accepted/Swift-rejected cases must either be implemented with byte-identical parity, documented as an approved security exception, or kept fail-closed with an explicit reason tied to the supported DMV profile.

If a future DMV credential profile requires broader nested context processing, that profile must be implemented through the final canonicalization engine rather than by adding one-off N-Quads generation.
