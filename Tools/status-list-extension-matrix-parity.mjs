#!/usr/bin/env node

import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {DataIntegrityProof}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/data-integrity/lib/index.js';
import {
  cryptosuite as ecdsaRdfc2019Cryptosuite
} from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/ecdsa-rdfc-2019-cryptosuite/lib/index.js';
import {JsonLdDocumentLoader}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/jsonld-document-loader/lib/index.js';
import {contexts as vcContexts}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/credentials-context/lib/index.js';

const verificationMethod = {
  id: 'did:web:uat-credentials.dmv.ca.gov#vm-vcb-1',
  type: 'Multikey',
  controller: 'did:web:uat-credentials.dmv.ca.gov',
  publicKeyMultibase: 'zDnaeVp3tjD8ipWSt42tBZJLCsDA9SrtYXGvLg5dL3qXtXDKP'
};

const baseCredential = {
  '@context': [
    'https://www.w3.org/ns/credentials/v2'
  ],
  id: 'https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists/revocation/0',
  type: [
    'VerifiableCredential',
    'BitstringStatusListCredential'
  ],
  credentialSubject: {
    id: 'https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists/revocation/0#list',
    type: 'BitstringStatusList',
    encodedList: 'uH4sIAAAAAAAAA2NhAAD717UlAgAAAA',
    statusPurpose: 'revocation'
  },
  issuer: 'did:web:uat-credentials.dmv.ca.gov',
  validFrom: '2026-01-01T00:00:00Z',
  proof: {
    type: 'DataIntegrityProof',
    created: '2026-01-01T00:00:00Z',
    verificationMethod: 'did:web:uat-credentials.dmv.ca.gov#vm-vcb-1',
    cryptosuite: 'ecdsa-rdfc-2019',
    proofPurpose: 'assertionMethod',
    proofValue: 'z3KqtjbQJZNSkeufgNj2oVRg9k9fZVoP5SroahjSNghZbU9osz8sL2J4beC9gWoNTkjDn6W9FBJRirMnNt4HuXvcw'
  }
};

const cases = [
  {id: 'string-literal', value: 'status string'},
  {id: 'integer-literal', value: 86400},
  {id: 'double-literal', value: 8.25},
  {id: 'boolean-literal', value: true},
  {id: 'null-omission', value: null},
  {id: 'mixed-array', value: ['array string', 3, false, null]},
  {
    id: 'absolute-id-node',
    value: {
      '@id': 'https://example.test/status/matrix/node',
      '@type': 'https://example.test/status/MatrixNode',
      'https://example.test/status/name': 'Node'
    }
  },
  {
    id: 'explicit-blank-node',
    value: {
      '@id': '_:statusMatrixExplicit',
      'https://example.test/status/name': 'Explicit blank'
    }
  },
  {
    id: 'generated-blank-node',
    value: {
      '@type': 'https://example.test/status/GeneratedBlank',
      'https://example.test/status/name': 'Generated blank'
    }
  },
  {
    id: 'reverse-id-node',
    value: {
      '@reverse': {
        'https://example.test/status/reverse': {
          '@id': 'https://example.test/status/reverse-source'
        }
      }
    }
  },
  {
    id: 'reverse-blank-node',
    value: {
      '@reverse': {
        'https://example.test/status/reverse': {
          'https://example.test/status/name': 'Reverse blank'
        }
      }
    }
  },
  {
    id: 'named-graph',
    value: {
      '@id': 'https://example.test/status/graph-owner',
      '@graph': {
        '@id': 'https://example.test/status/in-graph',
        'https://example.test/status/graphName': 'In graph'
      }
    }
  },
  {
    id: 'included-node',
    value: {
      '@included': {
        '@id': 'https://example.test/status/included',
        'https://example.test/status/name': 'Included'
      }
    }
  },
  {
    id: 'included-blank-node',
    value: {
      '@included': {
        'https://example.test/status/name': 'Included blank'
      }
    }
  },
  {
    id: 'nested-properties',
    value: {
      '@nest': {
        'https://example.test/status/nestedName': 'Nested'
      }
    }
  },
  {
    id: 'typed-value',
    value: {
      '@value': '7',
      '@type': 'http://www.w3.org/2001/XMLSchema#integer'
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
      '@value': 'Status direction',
      '@direction': 'ltr'
    }
  },
  {
    id: 'json-value',
    value: {
      '@value': {b: 2, a: [true, null, 'x']},
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
        {'@id': 'https://example.test/status/set-b'},
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
        {'@id': 'https://example.test/status/list-b'},
        {'https://example.test/status/listNested': 'nested'}
      ]
    }
  }
];

const results = [];
let failed = false;
for(const testCase of cases) {
  const result = await compareCase(testCase);
  failed = failed || !result.passed;
  results.push(result);
}

console.log(JSON.stringify({
  comparedFixtureCount: results.length,
  passed: !failed,
  results
}, null, 2));

if(failed) {
  process.exit(1);
}

async function compareCase(testCase) {
  const credential = credentialWithExtensions(testCase);
  const jsParts = await jsStatusListCanonicalParts(credential);
  const payload = JSON.stringify(credential);
  const swiftVerifyData = runJSON('swift', [
    'run',
    'CADMVVerifierOracle',
    '--status-list-verify-data'
  ], payload);
  const swiftDocument = runJSON('swift', [
    'run',
    'CADMVVerifierOracle',
    '--status-list-document-nquads'
  ], payload);
  const swiftProof = runJSON('swift', [
    'run',
    'CADMVVerifierOracle',
    '--status-list-proof-nquads'
  ], payload);
  const failures = [];
  if(jsParts.verifyDataHex !== swiftVerifyData.result.verifyDataHex) {
    failures.push('status-list verify-data mismatch');
  }
  if(jsParts.documentCanonicalNQuads !== swiftDocument.result.canonicalNQuads) {
    failures.push('status-list document canonical N-Quads mismatch');
  }
  if(jsParts.proofCanonicalNQuads !== swiftProof.result.canonicalNQuads) {
    failures.push('status-list proof canonical N-Quads mismatch');
  }
  return {
    id: `status-list-${testCase.id}`,
    jsVerifyDataHex: jsParts.verifyDataHex,
    swiftVerifyDataHex: swiftVerifyData.result.verifyDataHex,
    jsDocumentCanonicalNQuadsSHA256: sha256Hex(jsParts.documentCanonicalNQuads),
    swiftDocumentCanonicalNQuadsSHA256: sha256Hex(swiftDocument.result.canonicalNQuads),
    jsProofCanonicalNQuadsSHA256: sha256Hex(jsParts.proofCanonicalNQuads),
    swiftProofCanonicalNQuadsSHA256: sha256Hex(swiftProof.result.canonicalNQuads),
    passed: failures.length === 0,
    failures
  };
}

function credentialWithExtensions(testCase) {
  const credential = structuredClone(baseCredential);
  credential[`https://example.test/status/matrix/root/${testCase.id}`] =
    structuredClone(testCase.value);
  credential.credentialSubject[`https://example.test/status/matrix/subject/${testCase.id}`] =
    structuredClone(testCase.value);
  credential.proof[`https://example.test/status/matrix/proof/${testCase.id}`] =
    structuredClone(testCase.value);
  return credential;
}

async function jsStatusListCanonicalParts(credential) {
  const proof = credential.proof;
  const document = structuredClone(credential);
  delete document.proof;

  const jld = new JsonLdDocumentLoader();
  jld.addDocuments({documents: vcContexts});
  const dataIntegrityProof = new DataIntegrityProof({
    cryptosuite: ecdsaRdfc2019Cryptosuite
  });
  const documentLoader = jld.build();
  const c14nOptions = {
    documentLoader,
    safe: true,
    base: null,
    skipExpansion: false,
    messageDigestAlgorithm: 'SHA-256'
  };
  const proofDocument = {
    '@context': document['@context'],
    ...proof
  };
  dataIntegrityProof.ensureSuiteContext({
    document: proofDocument,
    addSuiteContext: true
  });
  delete proofDocument.proofValue;
  const [verifyData, documentCanonicalNQuads, proofCanonicalNQuads] =
    await Promise.all([
      ecdsaRdfc2019Cryptosuite.createVerifyData({
        cryptosuite: ecdsaRdfc2019Cryptosuite,
        document,
        proof,
        documentLoader,
        dataIntegrityProof,
        verificationMethod
      }),
      ecdsaRdfc2019Cryptosuite.canonize(document, c14nOptions),
      ecdsaRdfc2019Cryptosuite.canonize(proofDocument, c14nOptions)
    ]);
  return {
    verifyDataHex: Buffer.from(verifyData).toString('hex'),
    documentCanonicalNQuads,
    proofCanonicalNQuads
  };
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
