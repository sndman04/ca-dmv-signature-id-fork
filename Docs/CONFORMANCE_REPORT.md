# Conformance Report

Generated: 2026-07-04T03:08:57.528Z
Repository revision: `5bf7cbb`
Reference SDK: `cadmv-dlid-verifier-sdk@0.0.1-0`

This report is generated from committed non-PII fixtures and synthetic cases. It does not include raw PDF417 payloads, decoded identity fields, or real private scan data.

Overall result: PASS

## Gate Summary

| Gate | Command | Cases | Result |
| --- | --- | ---: | --- |
| Official UAT Fixture Parity | `node Tools/parity-compare.mjs` | 2 | PASS |
| Generated Signature Parity | `node Tools/generated-signature-parity.mjs` | 8 | PASS |
| Deterministic Mutation Parity | `node Tools/mutation-parity.mjs` | 3 | PASS |
| Status-List Verify-Data And N-Quads Parity | `node Tools/status-list-parity.mjs` | 3 | PASS |
| Generic VCB JSON-LD Extension N-Quads Parity | `node Tools/generic-jsonld-extension-parity.mjs` | 1 | PASS |
| Generic Proof JSON-LD Extension N-Quads Parity | `node Tools/generic-proof-extension-parity.mjs` | 1 | PASS |
| JSON-LD Extension Matrix N-Quads Parity | `node Tools/jsonld-extension-matrix-parity.mjs` | 48 | PASS |
| JSON-LD 1.1 Behavior Characterization | `node Tools/jsonld-behavior-characterization.mjs` | 17 | PASS |
| Canonicalization Engine Differential | `node Tools/canonicalization-engine-differential.mjs` | 9 | PASS |
| W3C RDFC-1.0 Conformance Subset | `Tools/swift-test.sh --filter RDFDatasetCanonicalizerTests/testW3CRDFC10ConformanceSubset` | 1 | PASS |
| W3C RDFC-1.0 Issued-Identifier Map Subset | `Tools/swift-test.sh --filter RDFDatasetCanonicalizerTests/testW3CRDFC10IssuedIdentifierMapSubset` | 1 | PASS |
| W3C RDFC-1.0 Negative Clique Fail-Closed Coverage | `Tools/swift-test.sh --filter RDFDatasetCanonicalizerTests/testW3CRDFC10NegativeCliqueGraphFailsClosed` | 1 | PASS |

## Covered Cases

### Official UAT Fixture Parity

- Result: PASS
- Compared cases: 2
- Duration: 1753 ms
- Case IDs:
  - `official-valid-uat`
  - `official-invalid-uat`

### Generated Signature Parity

- Result: PASS
- Compared cases: 8
- Duration: 5781 ms
- Case IDs:
  - `generated-valid-z-signature`
  - `generated-valid-u-signature`
  - `generated-valid-with-status-signature`
  - `generated-valid-with-validity-dates-signature`
  - `generated-valid-with-status-and-validity-dates-signature`
  - `generated-expired-valid-signature`
  - `generated-tampered-proof-signature`
  - `generated-tampered-protected-aamva-field`

### Deterministic Mutation Parity

- Result: PASS
- Compared cases: 3
- Duration: 2494 ms
- Case IDs:
  - `mutation-invalid-vcb-base64`
  - `mutation-truncated-vcb-cbor`
  - `mutation-corrupt-compressed-vcb-value`

### Status-List Verify-Data And N-Quads Parity

- Result: PASS
- Compared cases: 3
- Duration: 4201 ms
- Case IDs:
  - `synthetic-status-list-base`
  - `synthetic-status-list-optional-fields`
  - `synthetic-status-list-absolute-iri-extensions`
- Notes:
  - synthetic-status-list-base: document N-Quads SHA-256 32f9e3eb0ef441494d9f35b40deed3703c7730e491db83245714e0a1475100c1; proof N-Quads SHA-256 93fa093cba64513885ce626317a174530e4d19527212094b1571d4b8e665a221
  - synthetic-status-list-optional-fields: document N-Quads SHA-256 754ba90533e8d44df66599957c68a3f9f2cccac0f1380c538f17926967783567; proof N-Quads SHA-256 93fa093cba64513885ce626317a174530e4d19527212094b1571d4b8e665a221
  - synthetic-status-list-absolute-iri-extensions: document N-Quads SHA-256 1d15024c7b48d02e11025b4a029596abc10e2a7b2b07b25f4f17c9ade58d0944; proof N-Quads SHA-256 ec9fbce00e29e40b866166154710d56d30addd0b536573065f2a8552ce80a6ed

### Generic VCB JSON-LD Extension N-Quads Parity

- Result: PASS
- Compared cases: 1
- Duration: 521 ms
- Case IDs:
  - `generic-jsonld-extension-values`

### Generic Proof JSON-LD Extension N-Quads Parity

- Result: PASS
- Compared cases: 1
- Duration: 520 ms
- Case IDs:
  - `generic-proof-extension-values`

### JSON-LD Extension Matrix N-Quads Parity

- Result: PASS
- Compared cases: 48
- Duration: 21981 ms
- Case IDs:
  - `vcb-document-string-literal`
  - `proof-string-literal`
  - `vcb-document-integer-literal`
  - `proof-integer-literal`
  - `vcb-document-double-literal`
  - `proof-double-literal`
  - `vcb-document-boolean-literal`
  - `proof-boolean-literal`
  - `vcb-document-null-omission`
  - `proof-null-omission`
  - `vcb-document-mixed-array`
  - `proof-mixed-array`
  - `vcb-document-absolute-id-node`
  - `proof-absolute-id-node`
  - `vcb-document-explicit-blank-node`
  - `proof-explicit-blank-node`
  - `vcb-document-generated-blank-node`
  - `proof-generated-blank-node`
  - `vcb-document-reverse-id-node`
  - `proof-reverse-id-node`
  - `vcb-document-reverse-blank-node`
  - `proof-reverse-blank-node`
  - `vcb-document-named-graph`
  - `proof-named-graph`
  - `vcb-document-included-node`
  - `proof-included-node`
  - `vcb-document-included-blank-node`
  - `proof-included-blank-node`
  - `vcb-document-nested-properties`
  - `proof-nested-properties`
  - `vcb-document-typed-value`
  - `proof-typed-value`
  - `vcb-document-language-value`
  - `proof-language-value`
  - `vcb-document-directed-language-value`
  - `proof-directed-language-value`
  - `vcb-document-directed-value`
  - `proof-directed-value`
  - `vcb-document-json-value`
  - `proof-json-value`
  - `vcb-document-scalar-set`
  - `proof-scalar-set`
  - `vcb-document-array-set`
  - `proof-array-set`
  - `vcb-document-scalar-list`
  - `proof-scalar-list`
  - `vcb-document-array-list`
  - `proof-array-list`
- Notes:
  - vcb-document-string-literal: vcb-document; N-Quads SHA-256 89e1fa7bb52f0c509bf6f6234b2535c2f066f43254e98755c06eb86f88579ae9
  - proof-string-literal: proof; N-Quads SHA-256 f9aa72a1b4835c92b23e722d603f79be454f106d687050654aeed802c9ae02af
  - vcb-document-integer-literal: vcb-document; N-Quads SHA-256 f3a2aa8ba6278f7cc1131297b11b2bd374f439fbbb96d7ccab32cd351732870d
  - proof-integer-literal: proof; N-Quads SHA-256 87562890de2fdde22139cde87b2a505f75bb624dfde2b3a996a7d749bd88611b
  - vcb-document-double-literal: vcb-document; N-Quads SHA-256 ed7ca1091e80e3a05778d2d667173445b59faf02ef5fbe90f0a30de540d85c92
  - proof-double-literal: proof; N-Quads SHA-256 0795368636ef97f72f3c70646dadf2e5a71dffad7b0d51a5765f95d540000b9b
  - vcb-document-boolean-literal: vcb-document; N-Quads SHA-256 abd8ea26cd1ceff81f9e50d118a971829421d07d506d0b3293df996c652500fb
  - proof-boolean-literal: proof; N-Quads SHA-256 a2d25ab52321f6c88d16124355a6514e23867330419307ba61f81de3529bf34e
  - vcb-document-null-omission: vcb-document; N-Quads SHA-256 1de08ebb241aa4dc1efd069be5d6e58b7950ee983a501d65246595eb3b1384e1
  - proof-null-omission: proof; N-Quads SHA-256 df88648dd3ee09ebdf5d5e8e2fdbaecd4e03acc32680ea20a4807d3b49fb2b61
  - vcb-document-mixed-array: vcb-document; N-Quads SHA-256 f5b3749c011fc25d1dd9507d203db0478ff29557f7d451747cadf59d5ae120f7
  - proof-mixed-array: proof; N-Quads SHA-256 4ec05161a56fce4fccd65ab93f3e0cf7beb01449801ead5d6c2c0c49b219af63
  - vcb-document-absolute-id-node: vcb-document; N-Quads SHA-256 bc7c80528228685eccb5090f394a374ac8c1a788855967f3e357447defe1e356
  - proof-absolute-id-node: proof; N-Quads SHA-256 1dce5480a68763df72f78c23bd4aa21c309c34db88354a40477bd6fa69846d31
  - vcb-document-explicit-blank-node: vcb-document; N-Quads SHA-256 54aabc6833e212b274f8a941117f9ecffdb1d2a1bb1ffbeb8baa5e0ad364b947
  - proof-explicit-blank-node: proof; N-Quads SHA-256 b57ea7d1d9b2ec004c9365c32bd5a6ba443eafb7d33c0cd9872716324c23ecfc
  - vcb-document-generated-blank-node: vcb-document; N-Quads SHA-256 cae5b3439c14e4a1ffb7fde19bd9f1b3563251308ee80c00cc6b750690db70d8
  - proof-generated-blank-node: proof; N-Quads SHA-256 f2f60f672a2ea1dc76fbfbe4bd1fc76642182e535cb9672403940feac0b8a18f
  - vcb-document-reverse-id-node: vcb-document; N-Quads SHA-256 f6256f5c06eeafcdb5e73dcc57c026279e8292925a49476283f4eb3cb09875b2
  - proof-reverse-id-node: proof; N-Quads SHA-256 bc97f2c482786a6ee135e4fb601461a10f6f1377b16d954e0b1c2a735651cda9
  - vcb-document-reverse-blank-node: vcb-document; N-Quads SHA-256 c0b30382c255c47676d45fb6edae276ffb74e2775cb6d2d2ab723ac7374cad4d
  - proof-reverse-blank-node: proof; N-Quads SHA-256 d48dbbe914c268124ca091f0a3ce9794edc8f8eef971db27f26f1dc0683f57c2
  - vcb-document-named-graph: vcb-document; N-Quads SHA-256 abd229e8c328066ba65f87e28d6abad18a4b35328d71b6d7985a998210b8f29d
  - proof-named-graph: proof; N-Quads SHA-256 85c4ec8bd0f5cbc47cc8066701fdda4bf2ac3597d828e78f5e2fcd97645ac5b7
  - vcb-document-included-node: vcb-document; N-Quads SHA-256 5ff99aa15f3fbb3478ad320305ff0a2380ae5c4076a6e402dacf98dd69d8b1f9
  - proof-included-node: proof; N-Quads SHA-256 78b880a20097c1d0bb3e4f33711db6f70940bb543b9337ecb34ba33a0dd709c4
  - vcb-document-included-blank-node: vcb-document; N-Quads SHA-256 61490e90e4e4ac4e61f71204d2ef7d9dd904f2a66ce307193e76067a9374805e
  - proof-included-blank-node: proof; N-Quads SHA-256 eda3447c493823d9b5b5cf99f7c39c46a351ed3b103ec8769c70705fe5e279ed
  - vcb-document-nested-properties: vcb-document; N-Quads SHA-256 291fe0b78af0c269905d3b96284924ccdf1a8116e2141b0ffd337d25cf409be5
  - proof-nested-properties: proof; N-Quads SHA-256 df29da27b21a63c4164d96c3ffc3fdc1eafca6df9d3e640a81974e9ae3a47c96
  - vcb-document-typed-value: vcb-document; N-Quads SHA-256 55d0fecbcbdc0108e0795134c0397a7a4c63657675c614e487f05b46479872f1
  - proof-typed-value: proof; N-Quads SHA-256 0e3bc167f8cb18250e6d5086b184d15a7f29f49127d201a2108d2913dd2c900a
  - vcb-document-language-value: vcb-document; N-Quads SHA-256 7633d582c4f1370cc4039293551be8aa9b202bdf77368edad39aa5e23271e5fc
  - proof-language-value: proof; N-Quads SHA-256 4bdd735da7bc58018964ebecac1d9292372b712a94f09ea7306c5e5faeca198d
  - vcb-document-directed-language-value: vcb-document; N-Quads SHA-256 7da57e771f31660ee7f6d19ca284672f7d7acb7f4592777860fb82757f36c47b
  - proof-directed-language-value: proof; N-Quads SHA-256 f85e4632d1d7932100bb1250374797e3976db799c26a9f231e34b07582ed63c7
  - vcb-document-directed-value: vcb-document; N-Quads SHA-256 c4099593eafdcfc45210cda4d36688c177fdf6cad9cc6755cee7d8ce88622230
  - proof-directed-value: proof; N-Quads SHA-256 9bad31c72ea5ff33e3005cc69b374ef994208ed9b59040e3b0a474ccf1e34afe
  - vcb-document-json-value: vcb-document; N-Quads SHA-256 5bfd5a36b2794c30b2a36ab867168796ae270a9f4d2610bf58bc5f4a53d1737e
  - proof-json-value: proof; N-Quads SHA-256 568f44646bbdb317ed57f6591769ddcc3ecbba1dd6d5a0d0e7bb2d6125a358a3
  - vcb-document-scalar-set: vcb-document; N-Quads SHA-256 f270e7bc14a6e203357babe76ea897e3682bbf45b74f87b69f6d735a489afb9e
  - proof-scalar-set: proof; N-Quads SHA-256 3128f01f928dd01fe00db7e6b2d89cf979b2633b5339c8d18a63926f998ae4a9
  - vcb-document-array-set: vcb-document; N-Quads SHA-256 cdf95a26bf01734e568b30c27e4d8812a5797b4c89388ba41bd4e545aa586c21
  - proof-array-set: proof; N-Quads SHA-256 49cfb984542552ebcfafa82c04e8a2a1d734a2849d1bde76db762c3f3809919c
  - vcb-document-scalar-list: vcb-document; N-Quads SHA-256 b884c1a68940a17545b8140073e403e97b99e42daeb67823650da98f06199768
  - proof-scalar-list: proof; N-Quads SHA-256 9767cefe29423f5c0d7ec5a46f7fa0cbe81dbc729b51a988d61b493e927472d1
  - vcb-document-array-list: vcb-document; N-Quads SHA-256 5eaeac8be1a6d7c14a91d7d6400452dff166090bec3fc53385554ffc6467fd4a
  - proof-array-list: proof; N-Quads SHA-256 fe0e6ae45864317d255f949346b632db7fa5ccd283c87099954355d00d2d5e47

### JSON-LD 1.1 Behavior Characterization

- Result: PASS
- Compared cases: 17
- Duration: 8457 ms
- Case IDs:
  - `implemented-absolute-id-node`
  - `implemented-nested-graph`
  - `implemented-json-literal`
  - `implemented-scalar-list`
  - `implemented-scalar-set`
  - `implemented-reverse-blank-node-subject`
  - `implemented-included-blank-node`
  - `fail-closed-relative-id-node`
  - `fail-closed-blank-node-id`
  - `fail-closed-invalid-blank-node-id`
  - `fail-closed-nested-context`
  - `fail-closed-compact-property`
  - `fail-closed-reverse-literal`
  - `fail-closed-type-language-conflict`
  - `fail-closed-invalid-direction`
  - `fail-closed-typed-json-object-absolute-iri`
  - `fail-closed-non-string-index`
- Notes:
  - implemented-absolute-id-node: implemented; JS accepted=true; Swift accepted=true
  - implemented-nested-graph: implemented; JS accepted=true; Swift accepted=true
  - implemented-json-literal: implemented; JS accepted=true; Swift accepted=true
  - implemented-scalar-list: implemented; JS accepted=true; Swift accepted=true
  - implemented-scalar-set: implemented; JS accepted=true; Swift accepted=true
  - implemented-reverse-blank-node-subject: implemented; JS accepted=true; Swift accepted=true
  - implemented-included-blank-node: implemented; JS accepted=true; Swift accepted=true
  - fail-closed-relative-id-node: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-blank-node-id: implemented; JS accepted=true; Swift accepted=true
  - fail-closed-invalid-blank-node-id: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-nested-context: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-compact-property: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-reverse-literal: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-type-language-conflict: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-invalid-direction: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-typed-json-object-absolute-iri: bothReject; JS accepted=false; Swift accepted=false
  - fail-closed-non-string-index: bothReject; JS accepted=false; Swift accepted=false

### Canonicalization Engine Differential

- Result: PASS
- Compared cases: 9
- Duration: 4030 ms
- Case IDs:
  - `engine-vcb-document`
  - `engine-data-integrity-proof`
  - `engine-status-list-document`
  - `engine-status-list-proof`
  - `engine-official-valid-uat-vcb-document`
  - `engine-official-valid-uat-proof`
  - `engine-official-invalid-uat-vcb-document`
  - `engine-official-invalid-uat-proof`
  - `engine-rejects-compact-unknown-vcb-field`
- Notes:
  - engine-vcb-document: vcbDocument; N-Quads SHA-256 711f1a0061a7de2fc19fdd3b44020647a4e9c24b88cd3212d9701cd1bb4ffe3d
  - engine-data-integrity-proof: dataIntegrityProof; N-Quads SHA-256 317e2786b39b0a763c1a51aefa756edfc4571214e920654a8ad91dbe70392ac8
  - engine-status-list-document: statusListDocument; N-Quads SHA-256 229f31e2c5b5c0652b46cad3a676ce8e65db9afc4867ff54cf70f464601cf2be
  - engine-status-list-proof: dataIntegrityProof; N-Quads SHA-256 ea8bbe8b6f2ce2862763ce62cce15d131e6d1fc5c233a370fa51b516d5492e29
  - engine-official-valid-uat-vcb-document: vcbDocument; N-Quads SHA-256 abbbb98c352b3775dd421c18f8b620f40b0e680cc8e4e4ee5486b6c3de3e710d
  - engine-official-valid-uat-proof: dataIntegrityProof; N-Quads SHA-256 15806ce019af44239dabfc6bd43fe9301277e1db8832f571d7f646806ba99fed
  - engine-official-invalid-uat-vcb-document: vcbDocument; N-Quads SHA-256 f6ed10f34b046214d5e6870e316e3ff8f86ae0ab2a45a510b39ea17a08172d0f
  - engine-official-invalid-uat-proof: dataIntegrityProof; N-Quads SHA-256 15806ce019af44239dabfc6bd43fe9301277e1db8832f571d7f646806ba99fed
  - engine-rejects-compact-unknown-vcb-field: vcbDocument; JS accepted=false; Swift accepted=false

### W3C RDFC-1.0 Conformance Subset

- Result: PASS
- Compared cases: 1
- Duration: 3892 ms
- Case IDs:
  - `w3c-rdfc-subset`

### W3C RDFC-1.0 Issued-Identifier Map Subset

- Result: PASS
- Compared cases: 1
- Duration: 524 ms
- Case IDs:
  - `w3c-rdfc-issued-map-subset`

### W3C RDFC-1.0 Negative Clique Fail-Closed Coverage

- Result: PASS
- Compared cases: 1
- Duration: 768 ms
- Case IDs:
  - `w3c-rdfc-negative-clique`

## Remaining Scope

- This report covers the selected official SDK baseline fixtures, generated non-PII fixtures, supported status-list parity fixtures, generic extension parity fixtures, JSON-LD behavior characterization cases, and the current W3C RDFC subset tests.
- It is not yet a final proof that handwritten canonical N-Quads have been removed from public verification.
- Final completion still requires the standards-grade or native-library-backed canonicalization engine described in `Docs/LONG_TERM_JS_PARITY_PLAN.md`.

