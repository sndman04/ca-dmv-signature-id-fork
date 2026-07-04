#!/usr/bin/env node

import {spawnSync} from 'node:child_process';
import fs from 'node:fs';

const fixtureSource = fs.readFileSync(
  new URL('../References/cadmv-dlid-verifier-sdk/tests/001-main.test.js',
    import.meta.url),
  'utf8'
);
const validUAT = extractStringLiteral('validUatExample', fixtureSource);
const validVCB = vcbValue(validUAT);

const cases = [
  {
    id: 'mutation-invalid-vcb-base64',
    payload: replaceVCB(validUAT, '***'),
    expectedStage: 'cborld-decode'
  },
  {
    id: 'mutation-truncated-vcb-cbor',
    payload: replaceVCB(validUAT, validVCB.slice(0, 20)),
    expectedStage: 'cborld-decode'
  },
  {
    id: 'mutation-corrupt-compressed-vcb-value',
    payload: replaceVCB(
      validUAT,
      `${validVCB.slice(0, -1)}${validVCB.endsWith('A') ? 'B' : 'A'}`
    ),
    expectedStage: 'cborld-decode'
  }
];

let failed = false;
const results = [];
for(const testCase of cases) {
  const js = runJSON(process.execPath, [
    'Tools/reference-runner.mjs',
    '--stdin',
    '--mode=uat'
  ], testCase.payload).result;
  const swift = runJSON('swift', [
    'run',
    'CADMVVerifierOracle',
    '--mode=uat'
  ], testCase.payload).result;
  const failures = [];
  if(js.valid !== false) {
    failures.push('JS mutation unexpectedly verified');
  }
  if(swift.verified !== false) {
    failures.push('Swift mutation unexpectedly verified');
  }
  if(js.firstFailureStage !== swift.firstFailureStage) {
    failures.push('first failure stage mismatch');
  }
  if(js.firstFailureStage !== testCase.expectedStage) {
    failures.push('unexpected JS failure stage');
  }
  if(swift.firstFailureStage !== testCase.expectedStage) {
    failures.push('unexpected Swift failure stage');
  }
  if(js.issuerAccepted !== swift.issuerAccepted) {
    failures.push('issuer applicability mismatch');
  }
  if(js.vcbRequired !== swift.vcbRequired) {
    failures.push('VCB requirement mismatch');
  }
  if(js.vcbByteLength !== swift.vcbByteLength) {
    failures.push('decoded VCB byte length mismatch');
  }
  if(js.aamvaHashHex !== null || swift.aamvaHashHex !== null) {
    failures.push('malformed VCB unexpectedly produced AAMVA hash');
  }
  if(js.verifyDataHex !== null || swift.verifyDataHex !== null) {
    failures.push('malformed VCB unexpectedly produced verify-data');
  }
  if(js.vcbProofCanonicalNQuads !== null ||
    swift.vcbProofCanonicalNQuads !== null) {
    failures.push('malformed VCB unexpectedly produced proof N-Quads');
  }
  if(js.vcbDocumentCanonicalNQuads !== null ||
    swift.vcbDocumentCanonicalNQuads !== null) {
    failures.push('malformed VCB unexpectedly produced document N-Quads');
  }
  const passed = failures.length === 0;
  failed ||= !passed;
  results.push({
    id: testCase.id,
    jsValid: js.valid,
    swiftVerified: swift.verified,
    jsFirstFailureStage: js.firstFailureStage,
    swiftFirstFailureStage: swift.firstFailureStage,
    swiftFailureReason: swift.failureReason,
    jsIssuerAccepted: js.issuerAccepted,
    swiftIssuerAccepted: swift.issuerAccepted,
    jsVCBRequired: js.vcbRequired,
    swiftVCBRequired: swift.vcbRequired,
    jsVCBByteLength: js.vcbByteLength,
    swiftVCBByteLength: swift.vcbByteLength,
    jsAamvaHashHex: js.aamvaHashHex,
    swiftAamvaHashHex: swift.aamvaHashHex,
    jsVerifyDataHex: js.verifyDataHex,
    swiftVerifyDataHex: swift.verifyDataHex,
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

function replaceVCB(payload, value) {
  return payload.replace(/ZCE[^\r]+/, `ZCE${value}`);
}

function vcbValue(payload) {
  const match = payload.match(/ZCE([^\r]+)/);
  if(!match) {
    throw new Error('Fixture does not contain a ZCE VCB field.');
  }
  return match[1];
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

function extractStringLiteral(name, source) {
  const pattern = new RegExp(`const ${name} = '((?:\\\\\\\\.|[^'])*)';`);
  const match = source.match(pattern);
  if(!match) {
    throw new Error(`Fixture not found: ${name}`);
  }
  return Function(`return '${match[1]}'`)();
}
