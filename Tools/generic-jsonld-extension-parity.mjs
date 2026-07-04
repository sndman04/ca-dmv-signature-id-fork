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

const extensionDocument = {
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
    '@type': [
      'https://example.invalid/types/Reference',
      'https://example.invalid/types/SecondReference'
    ],
    '@reverse': {
      'https://example.invalid/terms/pointsTo': {
        '@id': 'https://example.invalid/resources/source'
      }
    },
    '@graph': [
      {
        '@id': 'https://example.invalid/resources/in-graph',
        '@type': 'https://example.invalid/types/InGraph',
        'https://example.invalid/terms/graphName': 'In graph'
      }
    ],
    'https://example.invalid/terms/referenceName': 'Reference'
  },
  'https://example.invalid/terms/typedBlankNode': {
    '@type': 'https://example.invalid/types/BlankNode',
    'https://example.invalid/terms/blankNodeName': 'Typed blank node'
  },
  'https://example.invalid/terms/typedValue': {
    '@value': 'typed',
    '@type': 'https://example.invalid/types/Custom'
  },
  'https://example.invalid/terms/languageValue': {
    '@value': 'Hello',
    '@language': 'en-US'
  },
  'https://example.invalid/terms/numericValue': {
    '@value': 7.5
  },
  'https://example.invalid/terms/setValue': {
    '@set': [
      'set-a',
      {
        '@id': 'https://example.invalid/resources/set-b'
      },
      null
    ]
  },
  'https://example.invalid/terms/listValue': {
    '@list': [
      'list-a',
      {
        '@id': 'https://example.invalid/resources/list-b'
      },
      {
        'https://example.invalid/terms/listNested': 'nested'
      }
    ]
  },
  'https://example.invalid/terms/emptyList': {
    '@list': []
  }
};

const jsCanonicalNQuads = await canonizeEcdsaXi2023(extensionDocument, {
  documentLoader: buildContextOnlyLoader()
});
const swift = runJSON('swift', [
  'run',
  'CADMVVerifierOracle',
  '--vcb-document-nquads'
], JSON.stringify(extensionDocument));
const swiftCanonicalNQuads = swift.result.canonicalNQuads;
const passed = jsCanonicalNQuads === swiftCanonicalNQuads;

console.log(JSON.stringify({
  comparedFixtureCount: 1,
  passed,
  results: [{
    id: 'generic-jsonld-extension-values',
    jsCanonicalNQuads,
    swiftCanonicalNQuads,
    passed,
    failures: passed ? [] : ['VCB document canonical N-Quads mismatch']
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
