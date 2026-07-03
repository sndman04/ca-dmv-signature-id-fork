#!/usr/bin/env node

import fs from 'node:fs';
import {verify} from '../References/cadmv-dlid-verifier-sdk/lib/index.js';
import {
  createCryptosuite as createEcdsaXi2023Cryptosuite
} from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/ecdsa-xi-2023-cryptosuite/lib/index.js';
import {canonize as canonizeEcdsaXi2023}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/ecdsa-xi-2023-cryptosuite/lib/canonize.js';
import {JsonLdDocumentLoader}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/jsonld-document-loader/lib/index.js';
import {contexts as vcbContexts}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/vc-barcodes-context/lib/index.js';
import {contexts as vcContexts}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/credentials-context/lib/index.js';

const referenceSdkCommit = '03c5485513ff6f2de6b46950a159b8f2cd427859';
const args = new Set(process.argv.slice(2));

if(args.has('--stdin')) {
  await runStdinOracle();
} else {
  await runFixtureSummary();
}

async function runStdinOracle() {
  const data = fs.readFileSync(0, 'utf8');
  const mode = optionValue('--mode') ?? 'prod';
  const requireVcb = boolOption('--require-vcb');
  const verifyStatus = boolOption('--verify-status');

  let result;
  try {
    result = await verify({
      data,
      mode,
      requireVcb,
      verifyStatus,
      debug: true
    });
  } catch(e) {
    result = {
      valid: false,
      error: e,
      debug: null
    };
  }

  console.log(JSON.stringify({
    referenceSdkCommit,
    input: 'stdin',
    mode,
    requireVcb,
    verifyStatus,
    result: await summarizeResult(result)
  }, null, 2));
}

async function runFixtureSummary() {
  const testSourcePath = new URL(
    '../References/cadmv-dlid-verifier-sdk/tests/001-main.test.js',
    import.meta.url
  );
  const source = fs.readFileSync(testSourcePath, 'utf8');

  const validUAT = extractStringLiteral('validUatExample', source);
  const invalidUAT = extractStringLiteral('invalidUatExample', source);

  const valid = await verify({data: validUAT, mode: 'uat', debug: true});
  const invalid = await verify({data: invalidUAT, mode: 'uat', debug: true});
  const status = await verify({
    data: validUAT,
    mode: 'uat',
    verifyStatus: true,
    debug: true
  });

  const summary = {
    referenceSdkCommit,
    fixtures: {
      validUAT: await summarizeResult(valid),
      invalidUAT: await summarizeResult(invalid),
      validUATWithStatus: await summarizeResult(status)
    },
    knownStatusIssue:
      status.valid === false &&
      status.error?.message === 'Status error' &&
      status.error?.cause?.message === '"credentialStatus" property not found.'
  };

  console.log(JSON.stringify(summary, null, 2));

  if(valid.valid !== true) {
    throw new Error('Reference valid UAT fixture did not verify.');
  }
  if(invalid.valid !== false) {
    throw new Error('Reference invalid UAT fixture unexpectedly verified.');
  }
}

async function summarizeResult(result) {
  const debug = result.debug;
  const credential = debug?.credential;
  const statusResult = debug?.verifyResult?.statusResult;
  const error = result.error;
  const cause = error?.cause?.errors?.[0]?.message ??
    error?.cause?.message ??
    null;

  return {
    valid: result.valid === true,
    firstFailureStage: firstFailureStage({result, error, cause}),
    error: error?.message ?? null,
    cause,
    issuerAccepted: debug?.issuerAccepted ?? null,
    vcbRequired: debug?.vcbRequired ?? null,
    vcbPresent: debug?.vcbPresent ?? null,
    vcbByteLength: debug?.cborldBytes?.length ?? null,
    credentialProfile: credential ? {
      issuer: credential.issuer ?? null,
      proofCryptosuite: credential.proof?.cryptosuite ?? null,
      verificationMethod: credential.proof?.verificationMethod ?? null,
      protectedComponentIndex:
        credential.credentialSubject?.protectedComponentIndex ?? null,
      credentialStatusType: credential.credentialStatus?.type ?? null,
      statusListPresent: credential.credentialStatus !== undefined
    } : null,
    aamvaHashHex: debug?.aamvaHash ?
      Buffer.from(debug.aamvaHash).toString('hex') : null,
    verifyDataHex: await vcbVerifyDataHex(debug),
    vcbProofCanonicalNQuads: await vcbProofCanonicalNQuads(debug),
    vcbDocumentCanonicalNQuads: await vcbDocumentCanonicalNQuads(debug),
    status: statusResult ? {
      verified: statusResult.verified ?? null,
      error: statusResult.error?.message ?? null
    } : null
  };
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
  return canonizeEcdsaXi2023(proofConfig, {
    documentLoader: buildContextOnlyLoader()
  });
}

async function vcbDocumentCanonicalNQuads(debug) {
  const credential = debug?.credential;
  if(!credential) {
    return null;
  }

  const document = structuredClone(credential);
  delete document.proof;
  return canonizeEcdsaXi2023(document, {
    documentLoader: buildContextOnlyLoader()
  });
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
    documentLoader: buildContextOnlyLoader()
  });
  return Buffer.from(verifyData).toString('hex');
}

function buildContextOnlyLoader() {
  const jld = new JsonLdDocumentLoader();
  jld.addDocuments({documents: vcContexts});
  jld.addDocuments({documents: vcbContexts});
  return jld.build();
}

function firstFailureStage({result, error, cause}) {
  if(result.valid === true) {
    return null;
  }

  const message = error?.message ?? '';
  if(!message) {
    return 'aamva-applicability';
  }
  if(message.includes('AAMVA') ||
    message.includes('Issuer') ||
    message.includes('Invalid DAJ')) {
    return 'aamva-applicability';
  }
  if(message.includes('VC Barcode field') ||
    message.includes('VC Barcode data')) {
    return 'vcb-discovery';
  }
  if(message.includes('VC Barcode decode')) {
    return 'cborld-decode';
  }
  if(message.includes('Status')) {
    return 'data-integrity-status-list';
  }
  if(message.includes('Verify') || cause === 'Invalid signature.') {
    return 'data-integrity-vcb';
  }
  return 'public-result-mapping';
}

function optionValue(name) {
  for(const arg of args) {
    if(arg.startsWith(`${name}=`)) {
      return arg.slice(name.length + 1);
    }
  }
  return null;
}

function boolOption(name) {
  const value = optionValue(name);
  if(value !== null) {
    return ['1', 'true', 'yes'].includes(value.toLowerCase());
  }
  return args.has(name);
}

function extractStringLiteral(name, text) {
  const pattern = new RegExp(`const ${name} = '((?:\\\\\\\\.|[^'])*)';`);
  const match = text.match(pattern);
  if(!match) {
    throw new Error(`Fixture not found: ${name}`);
  }
  return Function(`return '${match[1]}'`)();
}
