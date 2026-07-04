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

const cases = [
  {
    id: 'implemented-absolute-id-node',
    classification: 'implemented',
    reason: 'Absolute @id node objects are needed for safe extension references.',
    extension: {
      '@id': 'https://example.invalid/resources/reference',
      'https://example.invalid/terms/name': 'Reference'
    }
  },
  {
    id: 'implemented-nested-graph',
    classification: 'implemented',
    reason: 'Named graphs are covered by the current generic extension subset.',
    extension: {
      '@id': 'https://example.invalid/resources/graph-owner',
      '@graph': {
        '@id': 'https://example.invalid/resources/in-graph',
        'https://example.invalid/terms/name': 'In graph'
      }
    }
  },
  {
    id: 'implemented-json-literal',
    classification: 'implemented',
    reason: 'JSON value objects are covered by the current generic extension subset.',
    extension: {
      '@value': {b: 2, a: [true, null, 'x']},
      '@type': '@json'
    }
  },
  {
    id: 'fail-closed-relative-id-node',
    classification: 'bothReject',
    reason: 'The JS SDK safe-mode canonicalizer and Swift both reject relative @id values for this profile.',
    extension: {
      '@id': 'relative-resource',
      'https://example.invalid/terms/name': 'Relative'
    }
  },
  {
    id: 'fail-closed-blank-node-id',
    classification: 'swiftFailClosed',
    reason: 'Explicit blank-node identifiers are not needed by the DMV profile and would require broader JSON-LD node identifier semantics.',
    extension: {
      '@id': '_:explicit',
      'https://example.invalid/terms/name': 'Explicit blank'
    }
  },
  {
    id: 'fail-closed-nested-context',
    classification: 'bothReject',
    reason: 'The JS SDK safe-mode canonicalizer and Swift both reject this nested context shape.',
    extension: {
      '@context': {
        name: 'https://example.invalid/terms/name'
      },
      name: 'Scoped context'
    }
  },
  {
    id: 'fail-closed-compact-property',
    classification: 'bothReject',
    reason: 'Compact unknown properties are rejected because they do not expand through the pinned DMV context set.',
    extension: {
      compactName: 'Compact'
    }
  },
  {
    id: 'fail-closed-reverse-literal',
    classification: 'bothReject',
    reason: 'JSON-LD rejects reverse properties whose values are literals.',
    extension: {
      '@reverse': {
        'https://example.invalid/terms/reverse': 'literal'
      }
    }
  },
  {
    id: 'fail-closed-type-language-conflict',
    classification: 'bothReject',
    reason: 'JSON-LD value objects cannot combine @type with @language or @direction.',
    extension: {
      '@value': 'conflict',
      '@type': 'https://example.invalid/types/Custom',
      '@language': 'en'
    }
  },
  {
    id: 'fail-closed-invalid-direction',
    classification: 'bothReject',
    reason: 'JSON-LD permits only ltr and rtl direction values.',
    extension: {
      '@value': 'bad direction',
      '@direction': 'up'
    }
  },
  {
    id: 'fail-closed-typed-json-object-absolute-iri',
    classification: 'bothReject',
    reason: 'The JS SDK accepts structured JSON values only with @type: @json, not the expanded rdf:JSON IRI spelling.',
    extension: {
      '@value': {a: 1},
      '@type': 'http://www.w3.org/1999/02/22-rdf-syntax-ns#JSON'
    }
  },
  {
    id: 'fail-closed-non-string-index',
    classification: 'bothReject',
    reason: 'The JS SDK safe-mode canonicalizer and Swift both reject non-string @index metadata.',
    extension: {
      '@index': 7,
      '@value': 'indexed'
    }
  }
];

const results = [];
let failed = false;
for(const testCase of cases) {
  const document = vcbDocument(testCase.extension);
  const js = await runJSCanonize(document);
  const swift = runSwiftCanonize(document);
  const result = evaluate(testCase, js, swift);
  failed = failed || !result.passed;
  results.push(result);
}

console.log(JSON.stringify({
  characterizedCaseCount: results.length,
  passed: !failed,
  results
}, null, 2));

if(failed) {
  process.exit(1);
}

function vcbDocument(extension) {
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
    'https://example.invalid/terms/characterized': extension
  };
}

async function runJSCanonize(document) {
  try {
    return {
      ok: true,
      canonicalNQuads: await canonizeEcdsaXi2023(document, {
        documentLoader: buildContextOnlyLoader()
      })
    };
  } catch(error) {
    return {
      ok: false,
      errorName: error.name,
      errorMessage: error.message
    };
  }
}

function runSwiftCanonize(document) {
  const result = spawnSync('swift', [
    'run',
    'CADMVVerifierOracle',
    '--vcb-document-nquads'
  ], {
    input: JSON.stringify(document),
    encoding: 'utf8',
    maxBuffer: 10 * 1024 * 1024
  });
  if(result.status === 0) {
    return {
      ok: true,
      canonicalNQuads: JSON.parse(result.stdout).result.canonicalNQuads
    };
  }
  return {
    ok: false,
    errorMessage: [result.stdout, result.stderr].filter(Boolean).join('\n')
  };
}

function evaluate(testCase, js, swift) {
  const failures = [];
  switch(testCase.classification) {
    case 'implemented':
      if(!js.ok) {
        failures.push('JS rejected implemented case');
      }
      if(!swift.ok) {
        failures.push('Swift rejected implemented case');
      }
      if(js.ok && swift.ok && js.canonicalNQuads !== swift.canonicalNQuads) {
        failures.push('canonical N-Quads mismatch');
      }
      break;
    case 'swiftFailClosed':
      if(!js.ok) {
        failures.push('JS no longer accepts fail-closed characterization case');
      }
      if(swift.ok) {
        failures.push('Swift accepted a case classified as fail-closed');
      }
      break;
    case 'bothReject':
      if(js.ok) {
        failures.push('JS accepted a case classified as bothReject');
      }
      if(swift.ok) {
        failures.push('Swift accepted a case classified as bothReject');
      }
      break;
    default:
      failures.push(`Unknown classification ${testCase.classification}`);
  }
  return {
    id: testCase.id,
    classification: testCase.classification,
    reason: testCase.reason,
    jsAccepted: js.ok,
    swiftAccepted: swift.ok,
    passed: failures.length === 0,
    failures
  };
}

function buildContextOnlyLoader() {
  const jld = new JsonLdDocumentLoader();
  jld.addDocuments({documents: vcContexts});
  jld.addDocuments({documents: vcbContexts});
  return jld.build();
}
