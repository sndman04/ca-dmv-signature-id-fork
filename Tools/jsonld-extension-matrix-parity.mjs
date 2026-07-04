#!/usr/bin/env node

import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {canonize as canonizeEcdsaXi2023}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/ecdsa-xi-2023-cryptosuite/lib/canonize.js';
import {JsonLdDocumentLoader}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/jsonld-document-loader/lib/index.js';
import {contexts as vcbContexts}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/vc-barcodes-context/lib/index.js';
import {contexts as vcContexts}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/credentials-context/lib/index.js';

const cases = [
  {
    id: 'string-literal',
    value: 'plain string'
  },
  {
    id: 'integer-literal',
    value: 42
  },
  {
    id: 'double-literal',
    value: 7.5
  },
  {
    id: 'boolean-literal',
    value: true
  },
  {
    id: 'null-omission',
    value: null
  },
  {
    id: 'mixed-array',
    value: [
      'array string',
      3,
      false,
      null
    ]
  },
  {
    id: 'absolute-id-node',
    value: {
      '@id': 'https://example.invalid/resources/node',
      '@type': 'https://example.invalid/types/Node',
      'https://example.invalid/terms/name': 'Node'
    }
  },
  {
    id: 'explicit-blank-node',
    value: {
      '@id': '_:matrixExplicit',
      'https://example.invalid/terms/name': 'Explicit blank'
    }
  },
  {
    id: 'generated-blank-node',
    value: {
      '@type': 'https://example.invalid/types/GeneratedBlank',
      'https://example.invalid/terms/name': 'Generated blank'
    }
  },
  {
    id: 'reverse-id-node',
    value: {
      '@reverse': {
        'https://example.invalid/terms/reverse': {
          '@id': 'https://example.invalid/resources/reverse-source'
        }
      }
    }
  },
  {
    id: 'reverse-blank-node',
    value: {
      '@reverse': {
        'https://example.invalid/terms/reverse': {
          'https://example.invalid/terms/name': 'Reverse blank'
        }
      }
    }
  },
  {
    id: 'named-graph',
    value: {
      '@id': 'https://example.invalid/resources/graph-owner',
      '@graph': {
        '@id': 'https://example.invalid/resources/in-graph',
        'https://example.invalid/terms/graphName': 'In graph'
      }
    }
  },
  {
    id: 'included-node',
    value: {
      '@included': {
        '@id': 'https://example.invalid/resources/included',
        'https://example.invalid/terms/name': 'Included'
      }
    }
  },
  {
    id: 'included-blank-node',
    value: {
      '@included': {
        'https://example.invalid/terms/name': 'Included blank'
      }
    }
  },
  {
    id: 'nested-properties',
    value: {
      '@nest': {
        'https://example.invalid/terms/nestedName': 'Nested'
      }
    }
  },
  {
    id: 'typed-value',
    value: {
      '@value': 'typed value',
      '@type': 'https://example.invalid/types/CustomDatatype'
    }
  },
  {
    id: 'language-value',
    value: {
      '@value': 'Hello',
      '@language': 'en-US'
    }
  },
  {
    id: 'directed-language-value',
    value: {
      '@value': 'مرحبا',
      '@language': 'ar',
      '@direction': 'rtl'
    }
  },
  {
    id: 'directed-value',
    value: {
      '@value': 'plain direction',
      '@direction': 'ltr'
    }
  },
  {
    id: 'json-value',
    value: {
      '@value': {
        b: 2,
        a: [true, null, 'x']
      },
      '@type': '@json'
    }
  },
  {
    id: 'scalar-set',
    value: {
      '@set': 'single set'
    }
  },
  {
    id: 'array-set',
    value: {
      '@set': [
        'set-a',
        {
          '@id': 'https://example.invalid/resources/set-b'
        },
        null
      ]
    }
  },
  {
    id: 'scalar-list',
    value: {
      '@list': 'single list'
    }
  },
  {
    id: 'array-list',
    value: {
      '@list': [
        'list-a',
        {
          '@id': 'https://example.invalid/resources/list-b'
        },
        {
          'https://example.invalid/terms/listNested': 'nested'
        }
      ]
    }
  },
  {
    id: 'empty-list',
    value: {
      '@list': []
    }
  }
];

const results = [];
let failed = false;
for(const testCase of cases) {
  for(const profile of ['vcb-document', 'proof']) {
    const result = await compareCase(profile, testCase);
    failed = failed || !result.passed;
    results.push(result);
  }
}

console.log(JSON.stringify({
  comparedFixtureCount: results.length,
  passed: !failed,
  results
}, null, 2));

if(failed) {
  process.exit(1);
}

async function compareCase(profile, testCase) {
  const document = profile === 'vcb-document' ?
    vcbDocument(testCase) :
    proofDocument(testCase);
  const jsCanonicalNQuads = await canonizeEcdsaXi2023(document, {
    documentLoader: buildContextOnlyLoader()
  });
  const swift = runJSON('swift', [
    'run',
    'CADMVVerifierOracle',
    profile === 'vcb-document' ? '--vcb-document-nquads' : '--proof-nquads'
  ], JSON.stringify(document));
  const swiftCanonicalNQuads = swift.result.canonicalNQuads;
  const passed = jsCanonicalNQuads === swiftCanonicalNQuads;
  return {
    id: `${profile}-${testCase.id}`,
    profile,
    jsCanonicalNQuadsSHA256: sha256Hex(jsCanonicalNQuads),
    swiftCanonicalNQuadsSHA256: sha256Hex(swiftCanonicalNQuads),
    passed,
    failures: passed ? [] : [`${profile} canonical N-Quads mismatch`]
  };
}

function vcbDocument(testCase) {
  return {
    '@context': [
      'https://www.w3.org/ns/credentials/v2',
      'https://w3id.org/vc-barcodes/v1'
    ],
    type: [
      'VerifiableCredential',
      'OpticalBarcodeCredential'
    ],
    issuer: 'did:web:uat-credentials.dmv.ca.gov',
    credentialSubject: {
      type: 'AamvaDriversLicenseScannableInformation',
      protectedComponentIndex: 'uAQID'
    },
    [`https://example.invalid/terms/matrix/${testCase.id}`]: testCase.value
  };
}

function proofDocument(testCase) {
  return {
    '@context': [
      'https://www.w3.org/ns/credentials/v2',
      'https://w3id.org/vc-barcodes/v1'
    ],
    type: 'DataIntegrityProof',
    cryptosuite: 'ecdsa-xi-2023',
    proofPurpose: 'assertionMethod',
    verificationMethod: 'did:web:uat-credentials.dmv.ca.gov#vm-vcb-1',
    created: '2026-01-01T00:00:00Z',
    expires: '2026-01-02T00:00:00Z',
    [`https://example.invalid/proof/matrix/${testCase.id}`]: testCase.value
  };
}

function buildContextOnlyLoader() {
  const jld = new JsonLdDocumentLoader();
  jld.addDocuments({documents: vcContexts});
  jld.addDocuments({documents: vcbContexts});
  return jld.build();
}

function runJSON(command, args, input) {
  const result = spawnSync(command, args, {
    input,
    encoding: 'utf8',
    maxBuffer: 10 * 1024 * 1024
  });
  if(result.status !== 0) {
    throw new Error([
      `${command} ${args.join(' ')} failed with status ${result.status}`,
      result.stdout,
      result.stderr
    ].filter(Boolean).join('\n'));
  }
  return JSON.parse(result.stdout);
}

function sha256Hex(value) {
  return createHash('sha256').update(value).digest('hex');
}
