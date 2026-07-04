#!/usr/bin/env node

import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {DataIntegrityProof}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/data-integrity/lib/index.js';
import {
  cryptosuite as ecdsaRdfc2019Cryptosuite
} from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/ecdsa-rdfc-2019-cryptosuite/lib/index.js';
import {canonize as canonizeEcdsaXi2023}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/ecdsa-xi-2023-cryptosuite/lib/canonize.js';
import {JsonLdDocumentLoader}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/jsonld-document-loader/lib/index.js';
import {contexts as vcbContexts}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/vc-barcodes-context/lib/index.js';
import {contexts as vcContexts}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/credentials-context/lib/index.js';

const verificationMethod = {
  id: 'did:web:uat-credentials.dmv.ca.gov#vm-vcb-1',
  type: 'Multikey',
  controller: 'did:web:uat-credentials.dmv.ca.gov',
  publicKeyMultibase: 'zDnaeVp3tjD8ipWSt42tBZJLCsDA9SrtYXGvLg5dL3qXtXDKP'
};

const vcbDocument = {
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
  'https://example.invalid/terms/reference': {
    '@id': 'did:web:issuer.example#resource',
    '@type': 'https://example.invalid/types/Reference',
    '@reverse': {
      'https://example.invalid/terms/pointsTo': {
        '@id': 'https://example.invalid/resources/source'
      }
    },
    '@graph': {
      '@id': 'https://example.invalid/resources/in-graph',
      'https://example.invalid/terms/graphName': 'In graph'
    },
    '@included': {
      '@id': 'https://example.invalid/resources/included',
      'https://example.invalid/terms/includedName': 'Included'
    },
    '@nest': {
      'https://example.invalid/terms/nestedName': 'Nested'
    },
    'https://example.invalid/terms/referenceName': 'Reference'
  },
  'https://example.invalid/terms/explicitBlankNode': {
    '@id': '_:explicit',
    'https://example.invalid/terms/explicitBlankName': 'Explicit blank node'
  },
  'https://example.invalid/terms/jsonValue': {
    '@value': {b: 2, a: [true, null, 'x']},
    '@type': '@json'
  },
  'https://example.invalid/terms/listValue': {
    '@list': [
      'list-a',
      {'@id': 'https://example.invalid/resources/list-b'},
      {'https://example.invalid/terms/listNested': 'nested'}
    ]
  }
};

const proofConfig = {
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
  'https://example.invalid/proof/reference': {
    '@id': 'did:web:issuer.example#proof-resource',
    '@type': 'https://example.invalid/types/ProofReference',
    '@reverse': {
      'https://example.invalid/proof/pointsTo': {
        '@id': 'https://example.invalid/resources/proof-source'
      }
    },
    '@graph': {
      '@id': 'https://example.invalid/resources/proof-in-graph',
      'https://example.invalid/proof/graphName': 'Proof graph'
    },
    '@included': {
      '@id': 'https://example.invalid/resources/proof-included',
      'https://example.invalid/proof/includedName': 'Proof included'
    },
    '@nest': {
      'https://example.invalid/proof/nestedName': 'Proof nested'
    },
    'https://example.invalid/proof/referenceName': 'Proof Reference'
  },
  'https://example.invalid/proof/explicitBlankNode': {
    '@id': '_:proofExplicit',
    'https://example.invalid/proof/explicitBlankName': 'Proof explicit blank'
  },
  'https://example.invalid/proof/jsonValue': {
    '@value': 'Proof JSON string',
    '@type': '@json'
  },
  'https://example.invalid/proof/listValue': {
    '@list': [
      'proof-list-a',
      9,
      true,
      {'https://example.invalid/proof/listNested': 'nested'}
    ]
  }
};

const statusListCredential = {
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
    statusPurpose: 'revocation',
    'https://example.test/status/statusExplicitBlankNode': {
      '@id': '_:statusExplicit',
      'https://example.test/status/statusExplicitBlankName': 'Status explicit blank'
    },
    'https://example.test/status/statusJSONValue': {
      '@value': [2, 1],
      '@type': '@json'
    }
  },
  issuer: 'did:web:uat-credentials.dmv.ca.gov',
  validFrom: '2026-01-01T00:00:00Z',
  proof: {
    type: 'DataIntegrityProof',
    created: '2026-01-01T00:00:00Z',
    verificationMethod: 'did:web:uat-credentials.dmv.ca.gov#vm-vcb-1',
    cryptosuite: 'ecdsa-rdfc-2019',
    proofPurpose: 'assertionMethod',
    proofValue: 'z3KqtjbQJZNSkeufgNj2oVRg9k9fZVoP5SroahjSNghZbU9osz8sL2J4beC9gWoNTkjDn6W9FBJRirMnNt4HuXvcw',
    'https://example.test/status/proofExplicitBlankNode': {
      '@id': '_:proofExplicit',
      'https://example.test/status/proofExplicitBlankName': 'Proof explicit blank'
    },
    'https://example.test/status/proofJSONValue': {
      '@value': {b: 2, a: 1},
      '@type': '@json'
    }
  }
};

const rejectionDocument = {
  ...vcbDocument,
  compactUnknown: 'must not be silently dropped'
};

const acceptanceCases = [
  {
    id: 'engine-vcb-document',
    profile: 'vcbDocument',
    jsCanonicalNQuads: () => jsVcbCanonicalNQuads(vcbDocument),
    swiftCanonicalNQuads: () => swiftCanonicalNQuads('--vcb-document-nquads', vcbDocument)
  },
  {
    id: 'engine-data-integrity-proof',
    profile: 'dataIntegrityProof',
    jsCanonicalNQuads: () => jsVcbCanonicalNQuads(proofConfig),
    swiftCanonicalNQuads: () => swiftCanonicalNQuads('--proof-nquads', proofConfig)
  },
  {
    id: 'engine-status-list-document',
    profile: 'statusListDocument',
    jsCanonicalNQuads: async () => (await jsStatusListCanonicalParts(statusListCredential)).documentCanonicalNQuads,
    swiftCanonicalNQuads: () => swiftCanonicalNQuads('--status-list-document-nquads', statusListCredential)
  },
  {
    id: 'engine-status-list-proof',
    profile: 'dataIntegrityProof',
    jsCanonicalNQuads: async () => (await jsStatusListCanonicalParts(statusListCredential)).proofCanonicalNQuads,
    swiftCanonicalNQuads: () => swiftCanonicalNQuads('--status-list-proof-nquads', statusListCredential)
  }
];

const rejectionCases = [
  {
    id: 'engine-rejects-compact-unknown-vcb-field',
    profile: 'vcbDocument',
    jsAccepted: async () => accepted(() => jsVcbCanonicalNQuads(rejectionDocument)),
    swiftAccepted: async () => accepted(() => swiftCanonicalNQuads('--vcb-document-nquads', rejectionDocument))
  }
];

const results = [];
let failed = false;

for(const testCase of acceptanceCases) {
  const [jsCanonicalNQuads, swiftCanonicalNQuadsValue] = await Promise.all([
    testCase.jsCanonicalNQuads(),
    testCase.swiftCanonicalNQuads()
  ]);
  const failures = jsCanonicalNQuads === swiftCanonicalNQuadsValue ?
    [] :
    [`${testCase.profile} canonical N-Quads mismatch`];
  const passed = failures.length === 0;
  failed = failed || !passed;
  results.push({
    id: testCase.id,
    profile: testCase.profile,
    kind: 'acceptance',
    jsCanonicalNQuadsSHA256: sha256Hex(jsCanonicalNQuads),
    swiftCanonicalNQuadsSHA256: sha256Hex(swiftCanonicalNQuadsValue),
    passed,
    failures
  });
}

for(const testCase of rejectionCases) {
  const [jsAccepted, swiftAccepted] = await Promise.all([
    testCase.jsAccepted(),
    testCase.swiftAccepted()
  ]);
  const failures = jsAccepted === swiftAccepted ?
    [] :
    [`${testCase.profile} accept/reject behavior mismatch`];
  const passed = failures.length === 0;
  failed = failed || !passed;
  results.push({
    id: testCase.id,
    profile: testCase.profile,
    kind: 'rejection',
    jsAccepted,
    swiftAccepted,
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

async function jsVcbCanonicalNQuads(document) {
  return canonizeEcdsaXi2023(document, {
    documentLoader: buildVcbContextLoader()
  });
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
  const [documentCanonicalNQuads, proofCanonicalNQuads] = await Promise.all([
    ecdsaRdfc2019Cryptosuite.canonize(document, c14nOptions),
    ecdsaRdfc2019Cryptosuite.canonize(proofDocument, c14nOptions)
  ]);
  return {
    documentCanonicalNQuads,
    proofCanonicalNQuads
  };
}

function buildVcbContextLoader() {
  const jld = new JsonLdDocumentLoader();
  jld.addDocuments({documents: vcContexts});
  jld.addDocuments({documents: vcbContexts});
  return jld.build();
}

async function swiftCanonicalNQuads(option, document) {
  const swift = runJSON('swift', [
    'run',
    'CADMVVerifierOracle',
    option
  ], JSON.stringify(document));
  return swift.result.canonicalNQuads;
}

async function accepted(operation) {
  try {
    await operation();
    return true;
  } catch {
    return false;
  }
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
  return createHash('sha256').update(value, 'utf8').digest('hex');
}
