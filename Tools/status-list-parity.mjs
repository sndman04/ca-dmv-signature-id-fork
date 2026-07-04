#!/usr/bin/env node

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
    '@set': ['alpha', 'beta']
  },
  'https://example.test/status/rootList': {
    '@list': [
      'first',
      42,
      {
        '@id': 'https://example.test/status/list-node'
      }
    ]
  },
  'https://example.test/status/rootTypedNode': {
    '@type': 'https://example.test/status/RootType',
    'https://example.test/status/rootTypedName': 'typed root'
  },
  credentialSubject: {
    ...optionalFieldsFixture.credentialSubject,
    'https://example.test/status/subjectInteger': 86400,
    'https://example.test/status/subjectBoolean': true,
    'https://example.test/status/subjectNode': {
      '@id': 'https://example.test/status/subject-node',
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
        'https://example.test/status/statusGraphName': 'Status graph'
      },
      '@included': {
        '@id': 'https://example.test/status/status-included',
        'https://example.test/status/statusIncludedName': 'Status included'
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
      '@type': 'https://example.test/status/ProofType',
      '@reverse': {
        'https://example.test/status/proofPointsTo': {
          '@id': 'https://example.test/status/proof-source'
        }
      },
      '@graph': {
        '@id': 'https://example.test/status/proof-in-graph',
        'https://example.test/status/proofGraphName': 'Proof graph'
      },
      '@included': {
        '@id': 'https://example.test/status/proof-included',
        'https://example.test/status/proofIncludedName': 'Proof included'
      }
    },
    'https://example.test/status/proofTypedValue': {
      '@value': '7',
      '@type': 'http://www.w3.org/2001/XMLSchema#integer'
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
  const jsVerifyDataHex = await jsStatusListVerifyDataHex(fixture.credential);
  const swift = runJSON('swift', [
    'run',
    'CADMVVerifierOracle',
    '--status-list-verify-data'
  ], payload);
  const swiftVerifyDataHex = swift.result.verifyDataHex;
  const passed = jsVerifyDataHex === swiftVerifyDataHex;
  failed = failed || !passed;
  results.push({
    id: fixture.id,
    jsVerifyDataHex,
    swiftVerifyDataHex,
    passed,
    failures: passed ? [] : ['status-list verify-data mismatch']
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

async function jsStatusListVerifyDataHex(credential) {
  const proof = credential.proof;
  const document = structuredClone(credential);
  delete document.proof;

  const jld = new JsonLdDocumentLoader();
  jld.addDocuments({documents: vcContexts});
  const dataIntegrityProof = new DataIntegrityProof({
    cryptosuite: ecdsaRdfc2019Cryptosuite
  });
  const verifyData = await ecdsaRdfc2019Cryptosuite.createVerifyData({
    cryptosuite: ecdsaRdfc2019Cryptosuite,
    document,
    proof,
    documentLoader: jld.build(),
    dataIntegrityProof,
    verificationMethod
  });
  return Buffer.from(verifyData).toString('hex');
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
