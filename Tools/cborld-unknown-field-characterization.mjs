#!/usr/bin/env node

import {decode} from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/cborld/lib/index.js';
import {JsonLdDocumentLoader}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/jsonld-document-loader/lib/index.js';
import {contexts as vcbContexts}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/vc-barcodes-context/lib/index.js';
import {contexts as vcContexts}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/credentials-context/lib/index.js';

const cases = [
  {
    id: 'text-unknown-credential-key',
    bytes: credentialBytes({unknownCredentialKey: true}),
    expectDecoded: doc => doc.unknownCredentialOption === 'unsupported'
  },
  {
    id: 'text-unknown-proof-key',
    bytes: credentialBytes({unknownProofKey: true}),
    expectDecoded: doc => doc.proof?.unknownProofOption === 'unsupported'
  },
  {
    id: 'compressed-unknown-term-id',
    bytes: credentialBytes({compressedUnknownCredentialKey: true}),
    expectError: /Unknown term ID "999"/
  }
];

const documentLoader = buildContextOnlyLoader();
const typeTable = buildTypeTable();
const results = [];

for(const testCase of cases) {
  try {
    const decoded = await decode({
      cborldBytes: testCase.bytes,
      documentLoader,
      typeTableLoader: () => typeTable
    });
    const passed = testCase.expectDecoded?.(decoded) === true;
    results.push({
      id: testCase.id,
      decoded: true,
      passed,
      topLevelKeys: Object.keys(decoded).sort(),
      proofKeys: Object.keys(decoded.proof ?? {}).sort()
    });
  } catch(e) {
    const message = e?.message ?? String(e);
    const passed = testCase.expectError?.test(message) === true;
    results.push({
      id: testCase.id,
      decoded: false,
      passed,
      error: message
    });
  }
}

const passed = results.every(result => result.passed);
console.log(JSON.stringify({passed, results}, null, 2));

if(!passed) {
  process.exitCode = 1;
}

function buildContextOnlyLoader() {
  const jld = new JsonLdDocumentLoader();
  jld.addDocuments({documents: vcContexts});
  jld.addDocuments({documents: vcbContexts});
  return jld.build();
}

function buildTypeTable() {
  const contextTable = new Map([
    ['https://www.w3.org/ns/credentials/v2', 1],
    ['https://w3id.org/vc-barcodes/v1', 2]
  ]);
  const cryptosuiteTable = new Map([
    ['ecdsa-xi-2023', 1]
  ]);
  const urlTable = new Map([
    ['did:web:uat-credentials.dmv.ca.gov', 20],
    ['https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists', 21],
    ['did:web:uat-credentials.dmv.ca.gov#vm-vcb-1', 22]
  ]);
  const table = new Map();
  table.set('https://w3id.org/security#cryptosuiteString', cryptosuiteTable);
  table.set('context', contextTable);
  table.set('url', urlTable);
  return table;
}

function credentialBytes({
  unknownCredentialKey = false,
  unknownProofKey = false,
  compressedUnknownCredentialKey = false
} = {}) {
  const proofPairs = [
    [text('type'), text('DataIntegrityProof')],
    [text('cryptosuite'), text('ecdsa-xi-2023')],
    [text('proofPurpose'), text('assertionMethod')],
    [text('proofValue'), text('zLdp')],
    [text('verificationMethod'), text('did:web:uat-credentials.dmv.ca.gov#vm-vcb-1')]
  ];
  if(unknownProofKey) {
    proofPairs.push([text('unknownProofOption'), text('unsupported')]);
  }

  const credentialPairs = [
    [text('@context'), array([
      text('https://www.w3.org/ns/credentials/v2'),
      text('https://w3id.org/vc-barcodes/v1')
    ])],
    [text('type'), array([
      text('VerifiableCredential'),
      text('OpticalBarcodeCredential')
    ])],
    [text('issuer'), text('did:web:uat-credentials.dmv.ca.gov')],
    [text('credentialSubject'), map([
      [text('type'), text('AamvaDriversLicenseScannableInformation')],
      [text('protectedComponentIndex'), text('uAQID')]
    ])],
    [text('credentialStatus'), map([
      [text('type'), text('TerseBitstringStatusListEntry')],
      [
        text('terseStatusListBaseUrl'),
        text('https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists')
      ],
      [text('terseStatusListIndex'), unsigned(1)]
    ])],
    [text('proof'), map(proofPairs)]
  ];

  if(unknownCredentialKey) {
    credentialPairs.push([text('unknownCredentialOption'), text('unsupported')]);
  }
  if(compressedUnknownCredentialKey) {
    credentialPairs.push([unsigned(999), text('unsupported')]);
  }

  return Buffer.from(tagged(51_997, array([
    unsigned(31_000_000),
    map(credentialPairs)
  ])));
}

function unsigned(value) {
  return encode(0, value);
}

function text(value) {
  const bytes = [...Buffer.from(value, 'utf8')];
  return [...encode(3, bytes.length), ...bytes];
}

function array(values) {
  return [...encode(4, values.length), ...values.flat()];
}

function map(pairs) {
  return [...encode(5, pairs.length), ...pairs.flatMap(([key, value]) => [
    ...key,
    ...value
  ])];
}

function tagged(tag, value) {
  return [...encode(6, tag), ...value];
}

function encode(majorType, value) {
  const prefix = majorType << 5;
  if(value < 24) {
    return [prefix | value];
  }
  if(value <= 0xff) {
    return [prefix | 24, value];
  }
  if(value <= 0xffff) {
    return [prefix | 25, value >> 8, value & 0xff];
  }
  return [
    prefix | 26,
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff
  ];
}
