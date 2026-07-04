# Conformance Report

Generated: deterministic from current fixtures and reference gates
Report source: committed non-PII fixtures, generated synthetic cases, and the selected JavaScript reference SDK baseline
Reference SDK: `cadmv-dlid-verifier-sdk@0.0.1-0`

This report is generated from committed non-PII fixtures and synthetic cases. It does not include raw PDF417 payloads, decoded identity fields, or real private scan data.

Overall result: PASS

## Gate Summary

| Gate | Command | Cases | Result |
| --- | --- | ---: | --- |
| Official UAT Fixture Parity | `node Tools/parity-compare.mjs` | 2 | PASS |
| Generated Signature Parity | `node Tools/generated-signature-parity.mjs` | 14 | PASS |
| Deterministic Mutation Parity | `node Tools/mutation-parity.mjs` | 3 | PASS |
| Status-List Verify-Data And N-Quads Parity | `node Tools/status-list-parity.mjs` | 3 | PASS |
| Status Bit Boundary Parity | `node Tools/status-bit-parity.mjs` | 11 | PASS |
| Status-List Extension Matrix Verify-Data And N-Quads Parity | `node Tools/status-list-extension-matrix-parity.mjs` | 25 | PASS |
| Generic VCB JSON-LD Extension N-Quads Parity | `node Tools/generic-jsonld-extension-parity.mjs` | 1 | PASS |
| Generic Proof JSON-LD Extension N-Quads Parity | `node Tools/generic-proof-extension-parity.mjs` | 1 | PASS |
| JSON-LD Extension Matrix N-Quads Parity | `node Tools/jsonld-extension-matrix-parity.mjs` | 50 | PASS |
| JSON-LD 1.1 Behavior Characterization | `node Tools/jsonld-behavior-characterization.mjs` | 19 | PASS |
| Canonicalization Engine Differential | `node Tools/canonicalization-engine-differential.mjs` | 9 | PASS |
| W3C RDFC-1.0 Conformance Subset | `Tools/swift-test.sh --filter RDFDatasetCanonicalizerTests/testW3CRDFC10ConformanceSubset` | 1 | PASS |
| W3C RDFC-1.0 Issued-Identifier Map Subset | `Tools/swift-test.sh --filter RDFDatasetCanonicalizerTests/testW3CRDFC10IssuedIdentifierMapSubset` | 1 | PASS |
| W3C RDFC-1.0 Negative Clique Fail-Closed Coverage | `Tools/swift-test.sh --filter RDFDatasetCanonicalizerTests/testW3CRDFC10NegativeCliqueGraphFailsClosed` | 1 | PASS |

## Covered Cases

### Official UAT Fixture Parity

- Result: PASS
- Compared cases: 2
- Duration: omitted (runtime-dependent)
- Case IDs:
  - `official-valid-uat`
  - `official-invalid-uat`

### Generated Signature Parity

- Result: PASS
- Compared cases: 14
- Duration: omitted (runtime-dependent)
- Case IDs:
  - `generated-valid-z-signature`
  - `generated-valid-u-signature`
  - `generated-valid-with-status-signature`
  - `generated-valid-with-validity-dates-signature`
  - `generated-valid-with-status-and-validity-dates-signature`
  - `generated-valid-with-node-ids-signature`
  - `generated-valid-with-proof-expires-signature`
  - `generated-expired-valid-signature`
  - `generated-valid-with-expired-proof-expires-signature`
  - `generated-tampered-proof-signature`
  - `generated-tampered-proof-created`
  - `generated-tampered-proof-expires`
  - `generated-tampered-proof-verification-method`
  - `generated-tampered-protected-aamva-field`

### Deterministic Mutation Parity

- Result: PASS
- Compared cases: 3
- Duration: omitted (runtime-dependent)
- Case IDs:
  - `mutation-invalid-vcb-base64`
  - `mutation-truncated-vcb-cbor`
  - `mutation-corrupt-compressed-vcb-value`

### Status-List Verify-Data And N-Quads Parity

- Result: PASS
- Compared cases: 3
- Duration: omitted (runtime-dependent)
- Case IDs:
  - `synthetic-status-list-base`
  - `synthetic-status-list-optional-fields`
  - `synthetic-status-list-absolute-iri-extensions`
- Notes:
  - synthetic-status-list-base: document N-Quads SHA-256 32f9e3eb0ef441494d9f35b40deed3703c7730e491db83245714e0a1475100c1; proof N-Quads SHA-256 93fa093cba64513885ce626317a174530e4d19527212094b1571d4b8e665a221
  - synthetic-status-list-optional-fields: document N-Quads SHA-256 754ba90533e8d44df66599957c68a3f9f2cccac0f1380c538f17926967783567; proof N-Quads SHA-256 93fa093cba64513885ce626317a174530e4d19527212094b1571d4b8e665a221
  - synthetic-status-list-absolute-iri-extensions: document N-Quads SHA-256 1d15024c7b48d02e11025b4a029596abc10e2a7b2b07b25f4f17c9ade58d0944; proof N-Quads SHA-256 ec9fbce00e29e40b866166154710d56d30addd0b536573065f2a8552ce80a6ed

### Status Bit Boundary Parity

- Result: PASS
- Compared cases: 11
- Duration: omitted (runtime-dependent)
- Case IDs:
  - `status-bit-0-revoked`
  - `status-bit-7-revoked`
  - `status-bit-8-revoked`
  - `status-bit-63-revoked`
  - `status-bit-64-revoked`
  - `status-bit-71-revoked`
  - `status-bit-1-clear`
  - `status-bit-9-clear`
  - `status-bit-62-clear`
  - `status-bit-70-clear`
  - `status-bit-72-out-of-range`

### Status-List Extension Matrix Verify-Data And N-Quads Parity

- Result: PASS
- Compared cases: 25
- Duration: omitted (runtime-dependent)
- Case IDs:
  - `status-list-string-literal`
  - `status-list-integer-literal`
  - `status-list-double-literal`
  - `status-list-boolean-literal`
  - `status-list-null-omission`
  - `status-list-mixed-array`
  - `status-list-absolute-id-node`
  - `status-list-explicit-blank-node`
  - `status-list-generated-blank-node`
  - `status-list-reverse-id-node`
  - `status-list-reverse-blank-node`
  - `status-list-named-graph`
  - `status-list-included-node`
  - `status-list-included-blank-node`
  - `status-list-nested-properties`
  - `status-list-typed-value`
  - `status-list-language-value`
  - `status-list-directed-language-value`
  - `status-list-directed-value`
  - `status-list-json-value`
  - `status-list-scalar-set`
  - `status-list-array-set`
  - `status-list-scalar-list`
  - `status-list-array-list`
  - `status-list-empty-list`
- Notes:
  - status-list-string-literal: document N-Quads SHA-256 d96c8a6dfc319e2c03b3ab4e45dfe2f3a3454a2c871ed95089fe65108666ba50; proof N-Quads SHA-256 4be3abc2839305fcb40ac38e366817ec7ac941a9bb7d09d8b73a0acedb08561c
  - status-list-integer-literal: document N-Quads SHA-256 3228e287fd3268bba67fec006d3cd547572546c3d7c74977636acb0cd68579ba; proof N-Quads SHA-256 5989e3e410d84a71d41ad607321b310e2c0ba772326afff775441aebeff1ae3a
  - status-list-double-literal: document N-Quads SHA-256 62449b6bfa54db20f8d7d209c0498a9a3bdc7c9874c3d1d7d4e1f654c296a3fd; proof N-Quads SHA-256 6ae0be1dbb59b6e609a81e5cae289c5a5b4a3bfc63b599dd9ab429eef58c1ad6
  - status-list-boolean-literal: document N-Quads SHA-256 8fc1b3ce108d5a8a05e7160b4c071a464554f44ba24185b5c5814fb8cd45d54f; proof N-Quads SHA-256 f47ef74691c48266ffaaff389daa21703fa5d0df6eb155f727ceb4e8b9a69dc5
  - status-list-null-omission: document N-Quads SHA-256 32f9e3eb0ef441494d9f35b40deed3703c7730e491db83245714e0a1475100c1; proof N-Quads SHA-256 93fa093cba64513885ce626317a174530e4d19527212094b1571d4b8e665a221
  - status-list-mixed-array: document N-Quads SHA-256 be288610845583c36d00a7f9356374c9cdb500020f8c8588d0a52cfc95d50206; proof N-Quads SHA-256 8195250cf6e19bbbaa74e9c432a8d16cb4d607eea278748cc1a4ba261d65c8ee
  - status-list-absolute-id-node: document N-Quads SHA-256 728bb8cb942f1196194fd81b07ada5721edf4429f95cdf6d8ef6328325075cb7; proof N-Quads SHA-256 fc1bc635f4c49f4426d8778440b7afe87df2ea784fa4b309cd493a1966894cb1
  - status-list-explicit-blank-node: document N-Quads SHA-256 c91b8227564ae47d4f2809e64bbec6ecb242a6c791737ab39799b48b83bf7e3a; proof N-Quads SHA-256 1bbbe93bc3e4f4f8d1322f690b881b739d62dfefab4093abd5ce64b4f372514a
  - status-list-generated-blank-node: document N-Quads SHA-256 7ecb3c5e765d481f4aeade0bf38866de95faedef0f537cc1be5bfeaded63fea4; proof N-Quads SHA-256 ef89b3d43a4168624e95e8152c240f0e07ea0a48172ca21222b4d63404fc7c53
  - status-list-reverse-id-node: document N-Quads SHA-256 11bcd4b8421d5d26a508807b4e2ce5c20967992350f2b1c8b0ccf0d050c2eae6; proof N-Quads SHA-256 52151753366e97bed3af26a466840c555aafa3d0aa2dd0939432a7440a03736c
  - status-list-reverse-blank-node: document N-Quads SHA-256 addefc7461d55b4c636e18563b36c2ed0947774460dc24e6fd0bc3c2c29317cd; proof N-Quads SHA-256 d8d5b9b50db471e655d77a51484b4d12a3b752a4e717684fce6cdcae02666701
  - status-list-named-graph: document N-Quads SHA-256 bc994c8766faa859077da99eeda8348e0ae07f863e386bc9f206a5ed60ea82ef; proof N-Quads SHA-256 2dbaa6d788d931ca01b40d9a3f36a05c1655c4e1f3baf3f9e5e514b535400b30
  - status-list-included-node: document N-Quads SHA-256 d17f37618d4ba920d94c6f76b97169ec345d638e21cdcdf33e872351adfc7ccb; proof N-Quads SHA-256 deb3de5723747b81db76cba5978a12bcd2c71c991d0ef071795858fc875d7138
  - status-list-included-blank-node: document N-Quads SHA-256 68e60fc220156b200df23e7b9ad83b392534c40d8d1436359395cbe1912ee5a7; proof N-Quads SHA-256 4276878fce7a14475dcd3c7ad1527fcef7a51d10beae2ed20aff0e7b2599895c
  - status-list-nested-properties: document N-Quads SHA-256 8bf7669d6461e039412f363288de7536c2f9e1ee2cee76672633eff236a59e53; proof N-Quads SHA-256 fa595ef94e9358468ea0ff8e4361f283e78ba5c7831a41dc03f0e95227cba474
  - status-list-typed-value: document N-Quads SHA-256 7e833b4e174eb201a94d703dfaa81baa1a5971f906d23866be7ae3ab60073279; proof N-Quads SHA-256 771c0517fbfbc3c97d6db7e11ab03ab7e7efcf43abc511cac25b1fdf68e4311f
  - status-list-language-value: document N-Quads SHA-256 5c41f52dfe684027e097d097a5412cf62739cfe9be3597be46ea0d70d8dbe70c; proof N-Quads SHA-256 92df96a3e8af12b71bcf29f5d0ed83a48398824aa7dc48fa8368bba38b4dbe78
  - status-list-directed-language-value: document N-Quads SHA-256 ba2c562f6672a0a9c3e02dc60702488ba843c165205f4f4a2bcae65b10e1d972; proof N-Quads SHA-256 3df3505479cebcd62a19390f7e171ef46ce788a44b104908d0ce73e719c7b500
  - status-list-directed-value: document N-Quads SHA-256 d53eacc41d2aafe37518680cc27276fd047c7b3f6ecde5c7af3da35a5536f29a; proof N-Quads SHA-256 5590a481d0dcc3c20ee3ab5498aa258caa86707c0d31338f045c49fdae5e198b
  - status-list-json-value: document N-Quads SHA-256 7a6829aca445e7bb5dcd44d435c35b2dc64a89b15fc64aa62c4efc1cf91f3f51; proof N-Quads SHA-256 145f30bdcf104ec0dbe57a80933585daa460427b3ea4505d6dd01cd863389c61
  - status-list-scalar-set: document N-Quads SHA-256 c6b10e17512168c510b45652bc960f994393efa60d084247097ecab28610f08b; proof N-Quads SHA-256 1985adebccbf7b9b1a0959fada085dd6abf5e0e8bd04680f4b1a5599f3a4733e
  - status-list-array-set: document N-Quads SHA-256 d10a3e406a5a5db069025c5e94da689ac0692ca31493cc6f19c746c46f28d7c6; proof N-Quads SHA-256 b227ea285a841a16ba7f4c0d8c20a11c2ebd418d0d248c5ae80d8ad406583977
  - status-list-scalar-list: document N-Quads SHA-256 72224d5d4eb83c3162c1de08eda1a9de623aef4a6c44e001321103ae95b81ce2; proof N-Quads SHA-256 912375d598ef6b08bbc416e916a9666fb3e987b7a534982cec3f875b6211405e
  - status-list-array-list: document N-Quads SHA-256 9a82f62a5d3690eae0ef2ba48d3cedf6a6367e2434d473631717f5d8ba9747bb; proof N-Quads SHA-256 4d378be37a21255d0fa19c76ffe081c5686eb201a651d53a72b82e67a096b6c8
  - status-list-empty-list: document N-Quads SHA-256 cce71e1bae6a0974b5651f0083f41a731d447eb79770356c50be5d1729361738; proof N-Quads SHA-256 be6ff2d94ca8e07625d81734c113dec04c0acc66c8ec402b8a862124f39d6e84

### Generic VCB JSON-LD Extension N-Quads Parity

- Result: PASS
- Compared cases: 1
- Duration: omitted (runtime-dependent)
- Case IDs:
  - `generic-jsonld-extension-values`

### Generic Proof JSON-LD Extension N-Quads Parity

- Result: PASS
- Compared cases: 1
- Duration: omitted (runtime-dependent)
- Case IDs:
  - `generic-proof-extension-values`

### JSON-LD Extension Matrix N-Quads Parity

- Result: PASS
- Compared cases: 50
- Duration: omitted (runtime-dependent)
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
  - `vcb-document-empty-list`
  - `proof-empty-list`
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
  - vcb-document-empty-list: vcb-document; N-Quads SHA-256 eab05bdb96b1c572bae05de4313a5b992c097ab7798b16488d8a2090a338294e
  - proof-empty-list: proof; N-Quads SHA-256 89fc7cbcdedf87c2d264347e8f18c63eabf7ea1f417d189e1afe78ea0dab6f55

### JSON-LD 1.1 Behavior Characterization

- Result: PASS
- Compared cases: 19
- Duration: omitted (runtime-dependent)
- Case IDs:
  - `implemented-absolute-id-node`
  - `implemented-nested-graph`
  - `implemented-json-literal`
  - `implemented-scalar-list`
  - `implemented-scalar-set`
  - `implemented-reverse-blank-node-subject`
  - `implemented-included-blank-node`
  - `implemented-nest-object`
  - `implemented-empty-list`
  - `fail-closed-relative-id-node`
  - `implemented-blank-node-id`
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
  - implemented-nest-object: implemented; JS accepted=true; Swift accepted=true
  - implemented-empty-list: implemented; JS accepted=true; Swift accepted=true
  - fail-closed-relative-id-node: bothReject; JS accepted=false; Swift accepted=false
  - implemented-blank-node-id: implemented; JS accepted=true; Swift accepted=true
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
- Duration: omitted (runtime-dependent)
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
  - engine-vcb-document: vcbDocument; N-Quads SHA-256 f2eaee3bc41e59c29a00795fd79868195e1605a1f05ae0441069ba280368bdbf; production/supported-profile compared
  - engine-data-integrity-proof: dataIntegrityProof; N-Quads SHA-256 317e2786b39b0a763c1a51aefa756edfc4571214e920654a8ad91dbe70392ac8; production/supported-profile compared
  - engine-status-list-document: statusListDocument; N-Quads SHA-256 229f31e2c5b5c0652b46cad3a676ce8e65db9afc4867ff54cf70f464601cf2be; production/supported-profile compared
  - engine-status-list-proof: dataIntegrityProof; N-Quads SHA-256 ea8bbe8b6f2ce2862763ce62cce15d131e6d1fc5c233a370fa51b516d5492e29; production/supported-profile compared
  - engine-official-valid-uat-vcb-document: vcbDocument; N-Quads SHA-256 abbbb98c352b3775dd421c18f8b620f40b0e680cc8e4e4ee5486b6c3de3e710d; production/supported-profile compared
  - engine-official-valid-uat-proof: dataIntegrityProof; N-Quads SHA-256 15806ce019af44239dabfc6bd43fe9301277e1db8832f571d7f646806ba99fed; production/supported-profile compared
  - engine-official-invalid-uat-vcb-document: vcbDocument; N-Quads SHA-256 f6ed10f34b046214d5e6870e316e3ff8f86ae0ab2a45a510b39ea17a08172d0f; production/supported-profile compared
  - engine-official-invalid-uat-proof: dataIntegrityProof; N-Quads SHA-256 15806ce019af44239dabfc6bd43fe9301277e1db8832f571d7f646806ba99fed; production/supported-profile compared
  - engine-rejects-compact-unknown-vcb-field: vcbDocument; JS accepted=false; Swift production accepted=false; Swift supported-profile accepted=false

### W3C RDFC-1.0 Conformance Subset

- Result: PASS
- Compared cases: 1
- Duration: omitted (runtime-dependent)
- Case IDs:
  - `w3c-rdfc-subset`

### W3C RDFC-1.0 Issued-Identifier Map Subset

- Result: PASS
- Compared cases: 1
- Duration: omitted (runtime-dependent)
- Case IDs:
  - `w3c-rdfc-issued-map-subset`

### W3C RDFC-1.0 Negative Clique Fail-Closed Coverage

- Result: PASS
- Compared cases: 1
- Duration: omitted (runtime-dependent)
- Case IDs:
  - `w3c-rdfc-negative-clique`

## Supported Scope

- This report covers the selected official SDK baseline fixtures, generated non-PII fixtures, supported status-list parity fixtures, generic extension parity fixtures, JSON-LD behavior characterization cases, and the current W3C RDFC subset tests.
- Public verification routes through the native Swift DMV-profile JSON-LD/RDF canonicalization engine; JavaScript is retained only as a development and CI oracle.
- This is a California DMV DL/ID verifier conformance report, not a claim of general-purpose JSON-LD/Data Integrity SDK conformance.
