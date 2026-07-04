#!/usr/bin/env node

import {spawnSync} from 'node:child_process';
import {canonize as canonizeEcdsaXi2023}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/ecdsa-xi-2023-cryptosuite/lib/canonize.js';
import {JsonLdDocumentLoader}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/jsonld-document-loader/lib/index.js';
import {contexts as vcbContexts}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/vc-barcodes-context/lib/index.js';
import {contexts as vcContexts}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/credentials-context/lib/index.js';

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
    '@type': [
      'https://example.invalid/types/ProofReference',
      'https://example.invalid/types/SecondProofReference'
    ],
    '@reverse': {
      'https://example.invalid/proof/pointsTo': [
        {
          '@id': 'https://example.invalid/resources/proof-source'
        }
      ]
    },
    '@graph': {
      '@id': 'https://example.invalid/resources/proof-in-graph',
      '@type': 'https://example.invalid/types/ProofInGraph',
      'https://example.invalid/proof/graphName': 'Proof graph'
    },
    'https://example.invalid/proof/referenceName': 'Proof Reference'
  },
  'https://example.invalid/proof/typedBlankNode': {
    '@type': 'https://example.invalid/types/ProofBlankNode',
    'https://example.invalid/proof/blankNodeName': 'Typed proof blank node'
  },
  'https://example.invalid/proof/typedValue': {
    '@value': 'proof typed',
    '@type': 'https://example.invalid/types/ProofType'
  },
  'https://example.invalid/proof/languageValue': {
    '@value': 'Proof Hello',
    '@language': 'en-US'
  },
  'https://example.invalid/proof/setValue': {
    '@set': [
      'proof-set-a',
      {
        '@id': 'https://example.invalid/resources/proof-set-b'
      },
      null
    ]
  },
  'https://example.invalid/proof/listValue': {
    '@list': [
      'proof-list-a',
      9,
      true,
      {
        'https://example.invalid/proof/listNested': 'nested'
      }
    ]
  },
  'https://example.invalid/proof/emptyList': {
    '@list': []
  }
};

const jsCanonicalNQuads = await canonizeEcdsaXi2023(proofConfig, {
  documentLoader: buildContextOnlyLoader()
});
const swift = runJSON('swift', [
  'run',
  'CADMVVerifierOracle',
  '--proof-nquads'
], JSON.stringify(proofConfig));
const swiftCanonicalNQuads = swift.result.canonicalNQuads;
const passed = jsCanonicalNQuads === swiftCanonicalNQuads;

console.log(JSON.stringify({
  comparedFixtureCount: 1,
  passed,
  results: [{
    id: 'generic-proof-extension-values',
    jsCanonicalNQuads,
    swiftCanonicalNQuads,
    passed,
    failures: passed ? [] : ['proof canonical N-Quads mismatch']
  }]
}, null, 2));

if(!passed) {
  process.exit(1);
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
