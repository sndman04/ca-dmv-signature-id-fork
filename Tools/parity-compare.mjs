#!/usr/bin/env node

import {spawnSync} from 'node:child_process';
import fs from 'node:fs';

const fixtureSource = fs.readFileSync(
  new URL('../References/cadmv-dlid-verifier-sdk/tests/001-main.test.js',
    import.meta.url),
  'utf8'
);

const fixtures = [
  {
    id: 'official-valid-uat',
    mode: 'uat',
    payload: extractStringLiteral('validUatExample', fixtureSource)
  },
  {
    id: 'official-invalid-uat',
    mode: 'uat',
    payload: extractStringLiteral('invalidUatExample', fixtureSource)
  }
];

const results = [];
let failed = false;

for(const fixture of fixtures) {
  const js = runJSON(
    process.execPath,
    ['Tools/reference-runner.mjs', '--stdin', `--mode=${fixture.mode}`],
    fixture.payload
  );
  const swift = runJSON(
    'swift',
    ['run', 'CADMVVerifierOracle', `--mode=${fixture.mode}`],
    fixture.payload
  );

  const jsResult = js.result;
  const swiftResult = swift.result;
  const jsProfile = jsResult.credentialProfile;
  const swiftProfile = swiftResult.credentialProfile;
  const parity = {
    id: fixture.id,
    mode: fixture.mode,
    jsValid: jsResult.valid,
    swiftVerified: swiftResult.verified,
    jsFirstFailureStage: jsResult.firstFailureStage,
    swiftFirstFailureStage: swiftResult.firstFailureStage,
    jsAamvaHashHex: jsResult.aamvaHashHex,
    swiftAamvaHashHex: swiftResult.aamvaHashHex,
    jsVerifyDataHex: jsResult.verifyDataHex,
    swiftVerifyDataHex: swiftResult.verifyDataHex,
    jsVCBByteLength: jsResult.vcbByteLength,
    swiftVCBByteLength: swiftResult.vcbByteLength,
    jsCredentialProfile: jsProfile,
    swiftCredentialProfile: swiftProfile,
    passed: true,
    failures: []
  };

  if(jsResult.valid !== swiftResult.verified) {
    parity.passed = false;
    parity.failures.push('validity mismatch');
  }
  if(jsResult.firstFailureStage !== swiftResult.firstFailureStage) {
    parity.passed = false;
    parity.failures.push('first failure stage mismatch');
  }
  if(jsResult.aamvaHashHex !== swiftResult.aamvaHashHex) {
    parity.passed = false;
    parity.failures.push('AAMVA optical hash mismatch');
  }
  if(jsResult.verifyDataHex !== swiftResult.verifyDataHex) {
    parity.passed = false;
    parity.failures.push('VCB verify-data mismatch');
  }
  if(jsResult.vcbByteLength !== swiftResult.vcbByteLength) {
    parity.passed = false;
    parity.failures.push('VCB byte length mismatch');
  }
  if(!credentialProfilesMatch({jsProfile, swiftProfile, mode: fixture.mode})) {
    parity.passed = false;
    parity.failures.push('credential profile mismatch');
  }

  failed = failed || !parity.passed;
  results.push(parity);
}

console.log(JSON.stringify({
  comparedFixtureCount: results.length,
  passed: !failed,
  results
}, null, 2));

if(failed) {
  process.exit(1);
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

function credentialProfilesMatch({jsProfile, swiftProfile, mode}) {
  if(jsProfile === null || swiftProfile === null) {
    return jsProfile === swiftProfile;
  }

  const expectedShapeKey = mode === 'uat' ?
    'uatCredentialShapeValid' : 'productionCredentialShapeValid';
  const expectedOppositeShapeKey = mode === 'uat' ?
    'productionCredentialShapeValid' : 'uatCredentialShapeValid';

  return swiftProfile[expectedShapeKey] === true &&
    swiftProfile[expectedOppositeShapeKey] === false &&
    jsProfile.statusListPresent === swiftProfile.statusListPresent;
}

function extractStringLiteral(name, text) {
  const pattern = new RegExp(`const ${name} = '((?:\\\\\\\\.|[^'])*)';`);
  const match = text.match(pattern);
  if(!match) {
    throw new Error(`Fixture not found: ${name}`);
  }
  return Function(`return '${match[1]}'`)();
}
