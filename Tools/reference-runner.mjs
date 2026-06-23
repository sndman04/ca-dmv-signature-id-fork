#!/usr/bin/env node

import fs from 'node:fs';
import {verify} from '../References/cadmv-dlid-verifier-sdk/lib/index.js';

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
  referenceSdkCommit: '03c5485513ff6f2de6b46950a159b8f2cd427859',
  fixtures: {
    validUAT: summarizeResult(valid),
    invalidUAT: summarizeResult(invalid),
    validUATWithStatus: {
      valid: status.valid,
      error: status.error?.message ?? null,
      cause: status.error?.cause?.message ?? null
    }
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

function summarizeResult(result) {
  const credential = result.debug?.credential;
  return {
    valid: result.valid,
    issuerAccepted: result.debug?.issuerAccepted ?? null,
    vcbRequired: result.debug?.vcbRequired ?? null,
    vcbPresent: result.debug?.vcbPresent ?? null,
    vcbByteLength: result.debug?.cborldBytes?.length ?? null,
    issuer: credential?.issuer ?? null,
    proofCryptosuite: credential?.proof?.cryptosuite ?? null,
    verificationMethod: credential?.proof?.verificationMethod ?? null,
    protectedComponentIndex:
      credential?.credentialSubject?.protectedComponentIndex ?? null,
    aamvaHashHex: result.debug?.aamvaHash ?
      Buffer.from(result.debug.aamvaHash).toString('hex') : null,
    error: result.error?.message ?? null,
    cause: result.error?.cause?.errors?.[0]?.message ??
      result.error?.cause?.message ?? null
  };
}

function extractStringLiteral(name, text) {
  const pattern = new RegExp(`const ${name} = '((?:\\\\\\\\.|[^'])*)';`);
  const match = text.match(pattern);
  if(!match) {
    throw new Error(`Fixture not found: ${name}`);
  }
  return Function(`return '${match[1]}'`)();
}
