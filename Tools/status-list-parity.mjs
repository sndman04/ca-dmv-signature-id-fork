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

const baseFixture = {
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

const optionalFieldsFixture = {
  ...baseFixture,
  validUntil: '2026-01-02T00:00:00Z',
  name: 'Status List Credential',
  description: 'This credential expresses status information for some other credentials in an encoded and compressed list.'
};

const extensionFixture = {
  ...optionalFieldsFixture,
  'https://example.test/status/rootString': 'root extension',
  'https://example.test/status/rootSet': {
    '@index': 'root-set-index',
    '@set': ['alpha', 'beta']
  },
  'https://example.test/status/rootList': {
    '@index': 'root-list-index',
    '@list': [
      'first',
      42,
      {
        '@id': 'https://example.test/status/list-node'
      }
    ]
  },
  'https://example.test/status/rootTypedNode': {
    '@index': 'root-typed-node-index',
    '@type': 'https://example.test/status/RootType',
    'https://example.test/status/rootTypedName': 'typed root'
  },
  credentialSubject: {
    ...optionalFieldsFixture.credentialSubject,
    'https://example.test/status/subjectInteger': 86400,
    'https://example.test/status/subjectBoolean': true,
    'https://example.test/status/statusDirectedValue': {
      '@value': 'Status direction',
      '@direction': 'ltr'
    },
    'https://example.test/status/statusJSONValue': {
      '@value': [2, 1],
      '@type': '@json'
    },
    'https://example.test/status/statusExplicitBlankNode': {
      '@id': '_:statusExplicit',
      'https://example.test/status/statusExplicitBlankName': 'Status explicit blank'
    },
    'https://example.test/status/subjectNode': {
      '@id': 'https://example.test/status/subject-node',
      '@index': 'subject-node-index',
      '@type': [
        'https://example.test/status/SubjectType',
        'https://example.test/status/SecondSubjectType'
      ],
      '@reverse': {
        'https://example.test/status/statusPointsTo': {
          '@id': 'https://example.test/status/status-source'
        }
      },
      '@graph': {
        '@id': 'https://example.test/status/status-in-graph',
        '@index': 'subject-graph-index',
        'https://example.test/status/statusGraphName': 'Status graph'
      },
      '@included': {
        '@id': 'https://example.test/status/status-included',
        'https://example.test/status/statusIncludedName': 'Status included'
      },
      '@nest': {
        'https://example.test/status/statusNestedName': 'Status nested'
      },
      'https://example.test/status/nestedValue': {
        '@value': 'subject nested',
        '@language': 'en'
      }
    }
  },
  proof: {
    ...optionalFieldsFixture.proof,
    'https://example.test/status/proofString': 'proof extension',
    'https://example.test/status/proofNode': {
      '@id': 'https://example.test/status/proof-node',
      '@index': 'proof-node-index',
      '@type': 'https://example.test/status/ProofType',
      '@reverse': {
        'https://example.test/status/proofPointsTo': {
          '@id': 'https://example.test/status/proof-source'
        }
      },
      '@graph': {
        '@id': 'https://example.test/status/proof-in-graph',
        '@index': 'proof-graph-index',
        'https://example.test/status/proofGraphName': 'Proof graph'
      },
      '@included': {
        '@id': 'https://example.test/status/proof-included',
        'https://example.test/status/proofIncludedName': 'Proof included'
      },
      '@nest': {
        'https://example.test/status/proofNestedName': 'Proof nested'
      }
    },
    'https://example.test/status/proofTypedValue': {
      '@value': '7',
      '@index': 'proof-typed-value-index',
      '@type': 'http://www.w3.org/2001/XMLSchema#integer'
    },
    'https://example.test/status/proofDirectedValue': {
      '@value': 'Proof direction',
      '@direction': 'rtl'
    },
    'https://example.test/status/proofJSONValue': {
      '@value': {b: 2, a: 1},
      '@type': '@json'
    },
    'https://example.test/status/proofExplicitBlankNode': {
      '@id': '_:proofExplicit',
      'https://example.test/status/proofExplicitBlankName': 'Proof explicit blank'
    }
  }
};

const fixtures = [
  {id: 'synthetic-status-list-base', credential: baseFixture},
  {id: 'synthetic-status-list-optional-fields', credential: optionalFieldsFixture},
  {id: 'synthetic-status-list-absolute-iri-extensions', credential: extensionFixture}
];

const results = [];
let failed = false;

for(const fixture of fixtures) {
  const payload = JSON.stringify(fixture.credential);
  const jsParts = await jsStatusListCanonicalParts(fixture.credential);
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
  const swiftParts = {
    verifyDataHex: swiftVerifyData.result.verifyDataHex,
    documentCanonicalNQuads: swiftDocument.result.canonicalNQuads,
    proofCanonicalNQuads: swiftProof.result.canonicalNQuads
  };
  const failures = [];
  if(jsParts.verifyDataHex !== swiftParts.verifyDataHex) {
    failures.push('status-list verify-data mismatch');
  }
  if(jsParts.documentCanonicalNQuads !== swiftParts.documentCanonicalNQuads) {
    failures.push('status-list document canonical N-Quads mismatch');
  }
  if(jsParts.proofCanonicalNQuads !== swiftParts.proofCanonicalNQuads) {
    failures.push('status-list proof canonical N-Quads mismatch');
  }
  const passed = failures.length === 0;
  failed = failed || !passed;
  results.push({
    id: fixture.id,
    jsVerifyDataHex: jsParts.verifyDataHex,
    swiftVerifyDataHex: swiftParts.verifyDataHex,
    jsDocumentCanonicalNQuadsSHA256: sha256Hex(jsParts.documentCanonicalNQuads),
    swiftDocumentCanonicalNQuadsSHA256: sha256Hex(swiftParts.documentCanonicalNQuads),
    jsProofCanonicalNQuadsSHA256: sha256Hex(jsParts.proofCanonicalNQuads),
    swiftProofCanonicalNQuadsSHA256: sha256Hex(swiftParts.proofCanonicalNQuads),
    passed,
    failures
  });
}

console.log(JSON.stringify({
  comparedFixtureCount: results.length,
  passed: !failed,
  results
}, null, 2));

if(failed) {
  process.exit(1);
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

function sha256Hex(value) {
  return createHash('sha256').update(value, 'utf8').digest('hex');
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
