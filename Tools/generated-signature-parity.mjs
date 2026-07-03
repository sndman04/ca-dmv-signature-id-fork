#!/usr/bin/env node

import {spawnSync} from 'node:child_process';
import * as vc from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/vc/lib/index.js';
import {verify} from '../References/cadmv-dlid-verifier-sdk/lib/index.js';
import {aamva}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/pdf417-dl-canonicalizer/lib/index.js';
import {DataIntegrityProof}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/data-integrity/lib/index.js';
import {createCryptosuite as createEcdsaXi2023Cryptosuite}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/ecdsa-xi-2023-cryptosuite/lib/index.js';
import {encode}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/cborld/lib/index.js';
import {decode as decodeCBOR}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/.pnpm/cborg@5.1.3/node_modules/cborg/lib/decode.js';
import {Tagged}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/.pnpm/cborg@5.1.3/node_modules/cborg/lib/tagged.js';
import {JsonLdDocumentLoader}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/jsonld-document-loader/lib/index.js';
import {contexts as vcbContexts}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/vc-barcodes-context/lib/index.js';
import {contexts as vcContexts}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/credentials-context/lib/index.js';
import {contexts as securityContexts}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/.pnpm/@digitalbazaar+security-context@1.0.1/node_modules/@digitalbazaar/security-context/js/index.js';
import * as base58btc
  from '../References/cadmv-dlid-verifier-sdk/node_modules/.pnpm/base58-universal@2.0.0/node_modules/base58-universal/lib/index.js';
import * as ecdsaMultikey
  from '../References/cadmv-dlid-verifier-sdk/node_modules/.pnpm/@digitalbazaar+ecdsa-multikey@1.8.0/node_modules/@digitalbazaar/ecdsa-multikey/lib/index.js';

const issuer = 'did:web:uat-credentials.dmv.ca.gov';
const verificationMethod = `${issuer}#vm-vcb-1`;
const protectedComponentIndex = 'u___8';
const proofCreated = '2026-01-01T00:00:00Z';
const mode = 'uat';

const contextTable = new Map([
  ['https://www.w3.org/ns/credentials/v2', 1],
  ['https://w3id.org/vc-barcodes/v1', 2]
]);
const cryptosuiteTable = new Map([['ecdsa-xi-2023', 1]]);
const urlTable = new Map([
  ['did:web:credentials.dmv.ca.gov', 1],
  ['https://api.credentials.dmv.ca.gov/status/dlid/1/status-lists', 2],
  ['https://api.credentials.dmv.ca.gov/status/dlid/2/status-lists', 3],
  ['https://api.credentials.dmv.ca.gov/status/dlid/3/status-lists', 4],
  ['did:web:credentials.dmv.ca.gov#vm-vcb-1', 5],
  ['did:web:credentials.dmv.ca.gov#vm-vcb-2', 6],
  ['did:web:credentials.dmv.ca.gov#vm-vcb-3', 7],
  ['did:web:credentials.dmv.ca.gov#vm-vcb-4', 8],
  ['did:web:credentials.dmv.ca.gov#vm-vcb-5', 9],
  ['did:web:credentials.dmv.ca.gov#vm-vcb-6', 10],
  ['did:web:credentials.dmv.ca.gov#vm-vcb-7', 11],
  ['did:web:credentials.dmv.ca.gov#vm-vcb-8', 12],
  ['did:web:credentials.dmv.ca.gov#vm-vcb-9', 13],
  ['did:web:credentials.dmv.ca.gov#vm-vcb-10', 14],
  ['did:web:credentials.dmv.ca.gov#vm-vcb-11', 15],
  ['did:web:credentials.dmv.ca.gov#vm-vcb-12', 16],
  ['did:web:credentials.dmv.ca.gov#vm-vcb-13', 17],
  ['did:web:credentials.dmv.ca.gov#vm-vcb-14', 18],
  ['did:web:credentials.dmv.ca.gov#vm-vcb-15', 19],
  ['did:web:uat-credentials.dmv.ca.gov', 20],
  ['https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists', 21],
  ['did:web:uat-credentials.dmv.ca.gov#vm-vcb-1', 22],
  ['did:web:uat-credentials.dmv.ca.gov#vm-vcb-2', 23],
  ['did:web:uat-credentials.dmv.ca.gov#vm-vcb-3', 24],
  ['did:web:uat-credentials.dmv.ca.gov#vm-vcb-4', 25],
  ['did:web:uat-credentials.dmv.ca.gov#vm-vcb-5', 26],
  ['https://api.uat-credentials.dmv.ca.gov/status/dlid/2/status-lists', 27],
  ['https://api.uat-credentials.dmv.ca.gov/status/dlid/3/status-lists', 28]
]);
const typeTable = new Map();
typeTable.set('https://w3id.org/security#cryptosuiteString', cryptosuiteTable);
typeTable.set('context', contextTable);
typeTable.set('url', urlTable);

const keyPair = await ecdsaMultikey.generate({
  curve: 'P-256',
  id: verificationMethod,
  controller: issuer
});
const didDocument = {
  '@context': {
    id: '@id',
    type: '@type',
    assertionMethod: {
      '@id': 'https://w3id.org/security#assertionMethod',
      '@type': '@id',
      '@container': '@set'
    },
    controller: {
      '@id': 'https://w3id.org/security#controller',
      '@type': '@id'
    },
    Multikey: 'https://w3id.org/security#Multikey',
    publicKeyMultibase: 'https://w3id.org/security#publicKeyMultibase',
    verificationMethod: {
      '@id': 'https://w3id.org/security#verificationMethod',
      '@type': '@id',
      '@container': '@set'
    }
  },
  id: issuer,
  verificationMethod: [{
    id: verificationMethod,
    type: 'Multikey',
    controller: issuer,
    publicKeyMultibase: keyPair.publicKeyMultibase
  }],
  assertionMethod: [verificationMethod]
};
const documentLoader = buildDocumentLoader({didDocument});
const carrierForHash = makeAAMVABarcode({encodedVCB: 'AQID'});
const decodedCarrier = await aamva.decode({
  data: carrierForHash,
  encoding: 'utf8'
});
const protectedDocument = await aamva.select({
  object: decodedCarrier,
  selector: {
    subfile: ['DL', 'ID'],
    componentIndex: protectedComponentIndex
  }
});
const opticalHash = await aamva.hash({document: protectedDocument});
const signedCredential = await issueCredential(baseCredential());
const signedCredentialWithStatus = await issueCredential(baseCredential({
  credentialStatus: {
    type: 'TerseBitstringStatusListEntry',
    terseStatusListBaseUrl:
      'https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists',
    terseStatusListIndex: 42
  }
}));
const signedCredentialWithValidityDates = await issueCredential(baseCredential({
  validFrom: '2026-01-01T00:00:00Z',
  validUntil: '2030-01-01T00:00:00Z'
}));
const signedCredentialWithStatusAndValidityDates = await issueCredential(
  baseCredential({
    credentialStatus: {
      type: 'TerseBitstringStatusListEntry',
      terseStatusListBaseUrl:
        'https://api.uat-credentials.dmv.ca.gov/status/dlid/1/status-lists',
      terseStatusListIndex: 65535
    },
    validFrom: '2026-01-01T00:00:00Z',
    validUntil: '2030-01-01T00:00:00Z'
  })
);
const signedExpiredCredential = await issueCredential(baseCredential({
  validFrom: '2026-01-01T00:00:00Z',
  validUntil: '2026-01-02T00:00:00Z'
}));
const validZVCB = await encodeVCB(signedCredential);
const validUCredential = withProofValue(
  signedCredential,
  'u' + Buffer.from(base58btc.decode(
    signedCredential.proof.proofValue.slice(1))).toString('base64url')
);
const tamperedSignatureBytes = base58btc.decode(
  signedCredential.proof.proofValue.slice(1));
tamperedSignatureBytes[tamperedSignatureBytes.length - 1] ^= 0x01;
const tamperedSignatureCredential = withProofValue(
  signedCredential,
  'z' + base58btc.encode(tamperedSignatureBytes)
);

const fixtures = [
  {
    id: 'generated-valid-z-signature',
    payload: makeAAMVABarcode({encodedVCB: validZVCB}),
    expectVerified: true
  },
  {
    id: 'generated-valid-u-signature',
    payload: makeAAMVABarcode({encodedVCB: await encodeVCB(validUCredential)}),
    expectVerified: true
  },
  {
    id: 'generated-valid-with-status-signature',
    payload: makeAAMVABarcode({
      encodedVCB: await encodeVCB(signedCredentialWithStatus)
    }),
    expectVerified: true
  },
  {
    id: 'generated-valid-with-validity-dates-signature',
    payload: makeAAMVABarcode({
      encodedVCB: await encodeVCB(signedCredentialWithValidityDates)
    }),
    expectVerified: true
  },
  {
    id: 'generated-valid-with-status-and-validity-dates-signature',
    payload: makeAAMVABarcode({
      encodedVCB: await encodeVCB(signedCredentialWithStatusAndValidityDates)
    }),
    expectVerified: true
  },
  {
    id: 'generated-expired-valid-signature',
    payload: makeAAMVABarcode({
      encodedVCB: await encodeVCB(signedExpiredCredential)
    }),
    expectVerified: false,
    expectedStage: 'expiration'
  },
  {
    id: 'generated-tampered-proof-signature',
    payload: makeAAMVABarcode({
      encodedVCB: await encodeVCB(tamperedSignatureCredential)
    }),
    expectVerified: false,
    expectedStage: 'data-integrity-vcb'
  },
  {
    id: 'generated-tampered-protected-aamva-field',
    payload: makeAAMVABarcode({encodedVCB: validZVCB})
      .replace('DACSYNTHETIC', 'DACMUTATION'),
    expectVerified: false,
    expectedStage: 'data-integrity-vcb'
  }
];

let failed = false;
const results = [];
for(const fixture of fixtures) {
  const js = await verify({
    data: fixture.payload,
    mode,
    documentLoader,
    debug: true
  });
  const swift = runSwiftOracle({
    payload: fixture.payload,
    didDocument
  });
  const jsSummary = await summarizeJS(js);
  const swiftSummary = swift.result;
  const result = compare({fixture, jsSummary, swiftSummary});
  results.push(result);
  failed ||= !result.passed;
}

console.log(JSON.stringify({
  generatedFixtureCount: fixtures.length,
  passed: !failed,
  results
}, null, 2));
if(failed) {
  process.exitCode = 1;
}

async function issueCredential(credential) {
  return vc.issue({
    credential,
    suite: new DataIntegrityProof({
      date: proofCreated,
      signer: keyPair.signer(),
      cryptosuite: createEcdsaXi2023Cryptosuite({extraInformation: opticalHash})
    }),
    documentLoader
  });
}

function baseCredential(extra = {}) {
  return {
    '@context': [
      'https://www.w3.org/ns/credentials/v2',
      'https://w3id.org/vc-barcodes/v1'
    ],
    type: ['VerifiableCredential', 'OpticalBarcodeCredential'],
    issuer,
    credentialSubject: {
      type: 'AamvaDriversLicenseScannableInformation',
      protectedComponentIndex
    },
    ...extra
  };
}

function withProofValue(credential, proofValue) {
  return {
    ...structuredClone(credential),
    proof: {
      ...credential.proof,
      proofValue
    }
  };
}

async function encodeVCB(credential) {
  const cborldBytes = await encode({
    jsonldDocument: credential,
    documentLoader,
    registryEntryId: 31000000,
    typeTableLoader: () => typeTable
  });
  if(process.env.CADMV_DEBUG_GENERATED_CBOR === '1') {
    console.error(JSON.stringify(
      decodeCBOR(cborldBytes, {
        tags: Tagged.preserve(51997),
        useMaps: true
      }),
      cborJSONReplacer,
      2
    ));
  }
  return Buffer.from(cborldBytes).toString('base64');
}

function cborJSONReplacer(_key, value) {
  if(value instanceof Uint8Array) {
    return {
      byteStringHex: Buffer.from(value).toString('hex')
    };
  }
  if(value instanceof Map) {
    return {
      map: Array.from(value.entries())
    };
  }
  if(typeof value === 'bigint') {
    return value.toString();
  }
  return value;
}

function makeAAMVABarcode({encodedVCB}) {
  const elementSeparator = '\n';
  const recordSeparator = '\u001e';
  const segmentTerminator = '\r';
  const prefix = `@${elementSeparator}${recordSeparator}${segmentTerminator}ANSI `;
  const identitySubfile = [
    'DLDAQSYNTHETIC-DL',
    'DCAC',
    'DCBNONE',
    'DCDNONE',
    'DBA01012030',
    'DCSSYNTHETIC',
    'DACSYNTHETIC',
    'DADPARITY',
    'DBD01012024',
    'DBB01011990',
    'DBC1',
    'DAYBRO',
    'DAU070 in',
    'DAG123 MAIN ST',
    'DAISACRAMENTO',
    'DAJCA',
    'DAK942030000',
    'DCFSYNTHETICDCF',
    'DCGUSA',
    'DDEN',
    'DDFN',
    'DDGN'
  ].join(elementSeparator) + segmentTerminator;
  const zcSubfile = [
    'ZCZCA',
    `ZCE${encodedVCB}`
  ].join(elementSeparator) + segmentTerminator;
  const headerWithoutEntries = `${prefix}636014100102`;
  const entriesLength = 20;
  const identityOffset = headerWithoutEntries.length + entriesLength;
  const zcOffset = identityOffset + Buffer.byteLength(identitySubfile);
  const entries = [
    'DL',
    pad(identityOffset),
    pad(Buffer.byteLength(identitySubfile)),
    'ZC',
    pad(zcOffset),
    pad(Buffer.byteLength(zcSubfile))
  ].join('');
  return headerWithoutEntries + entries + identitySubfile + zcSubfile;
}

function pad(value) {
  return String(value).padStart(4, '0');
}

function buildDocumentLoader({didDocument}) {
  const jld = new JsonLdDocumentLoader();
  jld.addDocuments({documents: vcContexts});
  jld.addDocuments({documents: vcbContexts});
  jld.addDocuments({documents: securityContexts});
  const baseLoader = jld.build();
  return async url => {
    if(url === issuer) {
      return {
        contextUrl: null,
        documentUrl: url,
        document: didDocument
      };
    }
    if(url === verificationMethod) {
      return {
        contextUrl: null,
        documentUrl: url,
        document: didDocument.verificationMethod[0]
      };
    }
    return baseLoader(url);
  };
}

async function summarizeJS(result) {
  const debug = result.debug;
  return {
    verified: result.valid === true,
    firstFailureStage: firstFailureStage(result),
    error: result.error?.message ?? null,
    cause: result.error?.cause?.errors?.[0]?.message ??
      result.error?.cause?.message ??
      null,
    aamvaHashHex: debug?.aamvaHash ?
      Buffer.from(debug.aamvaHash).toString('hex') : null,
    verifyDataHex: await vcbVerifyDataHex(debug),
    vcbProofCanonicalNQuads: await vcbProofCanonicalNQuads(debug),
    vcbDocumentCanonicalNQuads: await vcbDocumentCanonicalNQuads(debug),
    vcbByteLength: debug?.cborldBytes?.length ?? null
  };
}

async function vcbVerifyDataHex(debug) {
  const credential = debug?.credential;
  const aamvaHash = debug?.aamvaHash;
  const proof = credential?.proof;
  if(!credential || !aamvaHash || !proof) {
    return null;
  }
  const document = structuredClone(credential);
  delete document.proof;
  const cryptosuite = createEcdsaXi2023Cryptosuite({
    extraInformation: aamvaHash
  });
  const verifyData = await cryptosuite.createVerifyData({
    cryptosuite,
    document,
    proof,
    documentLoader
  });
  return Buffer.from(verifyData).toString('hex');
}

async function vcbProofCanonicalNQuads(debug) {
  const credential = debug?.credential;
  const proof = credential?.proof;
  if(!credential || !proof) {
    return null;
  }
  const proofConfig = {
    '@context': credential['@context'],
    ...proof
  };
  delete proofConfig.proofValue;
  const {canonize} = await import(
    '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/ecdsa-xi-2023-cryptosuite/lib/canonize.js'
  );
  return canonize(proofConfig, {documentLoader});
}

async function vcbDocumentCanonicalNQuads(debug) {
  const credential = debug?.credential;
  if(!credential) {
    return null;
  }
  const document = structuredClone(credential);
  delete document.proof;
  const {canonize} = await import(
    '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/ecdsa-xi-2023-cryptosuite/lib/canonize.js'
  );
  return canonize(document, {documentLoader});
}

function firstFailureStage(result) {
  if(result.valid === true) {
    return null;
  }
  const error = result.error;
  const cause = error?.cause?.errors?.[0]?.message ??
    error?.cause?.message ??
    null;
  const message = error?.message ?? '';
  if(message.includes('validUntil') ||
    cause?.includes?.('validUntil') ||
    message.includes('expired') ||
    cause?.includes?.('expired')) {
    return 'expiration';
  }
  if(message.includes('Verify') || cause === 'Invalid signature.') {
    return 'data-integrity-vcb';
  }
  if(message.includes('VC Barcode decode')) {
    return 'cborld-decode';
  }
  return 'public-result-mapping';
}

function runSwiftOracle({payload, didDocument}) {
  const result = spawnSync(
    'swift',
    ['run', 'CADMVVerifierOracle', `--mode=${mode}`],
    {
      input: payload,
      encoding: 'utf8',
      maxBuffer: 10 * 1024 * 1024,
      env: {
        ...process.env,
        CADMV_ORACLE_DID_DOCUMENT_JSON: JSON.stringify(didDocument)
      }
    }
  );
  if(result.status !== 0) {
    throw new Error([
      `swift run CADMVVerifierOracle --mode=${mode} failed with status ${result.status}`,
      result.stdout,
      result.stderr
    ].filter(Boolean).join('\n'));
  }
  return JSON.parse(result.stdout);
}

function compare({fixture, jsSummary, swiftSummary}) {
  const result = {
    id: fixture.id,
    jsVerified: jsSummary.verified,
    swiftVerified: swiftSummary.verified,
    jsFirstFailureStage: jsSummary.firstFailureStage,
    swiftFirstFailureStage: swiftSummary.firstFailureStage,
    jsError: jsSummary.error,
    jsCause: jsSummary.cause,
    swiftFailureReason: swiftSummary.failureReason,
    jsAamvaHashHex: jsSummary.aamvaHashHex,
    swiftAamvaHashHex: swiftSummary.aamvaHashHex,
    jsVerifyDataHex: jsSummary.verifyDataHex,
    swiftVerifyDataHex: swiftSummary.verifyDataHex,
    jsVCBByteLength: jsSummary.vcbByteLength,
    swiftVCBByteLength: swiftSummary.vcbByteLength,
    passed: true,
    failures: []
  };
  const checks = [
    [jsSummary.verified === swiftSummary.verified, 'validity mismatch'],
    [jsSummary.verified === fixture.expectVerified, 'unexpected JS result'],
    [swiftSummary.verified === fixture.expectVerified, 'unexpected Swift result'],
    [
      jsSummary.firstFailureStage === swiftSummary.firstFailureStage,
      'first failure stage mismatch'
    ],
    [jsSummary.aamvaHashHex === swiftSummary.aamvaHashHex, 'AAMVA hash mismatch'],
    [jsSummary.verifyDataHex === swiftSummary.verifyDataHex, 'verify-data mismatch'],
    [
      jsSummary.vcbProofCanonicalNQuads ===
        swiftSummary.vcbProofCanonicalNQuads,
      'proof canonical N-Quads mismatch'
    ],
    [
      jsSummary.vcbDocumentCanonicalNQuads ===
        swiftSummary.vcbDocumentCanonicalNQuads,
      'document canonical N-Quads mismatch'
    ],
    [jsSummary.vcbByteLength === swiftSummary.vcbByteLength, 'VCB byte length mismatch']
  ];
  if(fixture.expectedStage) {
    checks.push([
      jsSummary.firstFailureStage === fixture.expectedStage,
      'unexpected JS failure stage'
    ]);
    checks.push([
      swiftSummary.firstFailureStage === fixture.expectedStage,
      'unexpected Swift failure stage'
    ]);
  }
  for(const [passed, failure] of checks) {
    if(!passed) {
      result.passed = false;
      result.failures.push(failure);
    }
  }
  return result;
}
