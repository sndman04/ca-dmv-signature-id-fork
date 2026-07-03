#!/usr/bin/env node

import {DataIntegrityProof}
  from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/data-integrity/lib/index.js';
import * as base58btc
  from '../References/cadmv-dlid-verifier-sdk/node_modules/.pnpm/base58-universal@2.0.0/node_modules/base58-universal/lib/index.js';

const rawSignature = Uint8Array.from({length: 64}, (_, i) => i);
const p256Order = BigInt(
  '0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551');
const cases = [
  {
    id: 'base58btc-z',
    proofValue: 'z' + base58btc.encode(rawSignature),
    expectedSignatureHex: hex(rawSignature)
  },
  {
    id: 'base64url-u',
    proofValue: 'u' + Buffer.from(rawSignature).toString('base64url'),
    expectedSignatureHex: hex(rawSignature)
  },
  {
    id: 'unsupported-prefix',
    proofValue: 'x' + base58btc.encode(rawSignature),
    expectedError: /Only base58btc or base64url multibase encoding/
  },
  {
    id: 'malformed-base58btc',
    proofValue: 'z0',
    expectedError: /Non-base58btc character|first argument/
  },
  {
    id: 'short-base64url-u',
    proofValue: 'uAQIDBA',
    expectedSignatureHex: '01020304'
  },
  {
    id: 'malformed-base64url-u',
    proofValue: 'u***',
    expectedSignatureHex: ''
  }
];

const results = [];
for(const testCase of cases) {
  const observed = {signatureHex: null};
  const proof = new DataIntegrityProof({
    type: 'DataIntegrityProof',
    cryptosuite: {
      name: 'ecdsa-xi-2023',
      requiredAlgorithm: 'P-256',
      createVerifier: async () => ({
        algorithm: 'P-256',
        async verify({signature}) {
          observed.signatureHex = hex(signature);
          return true;
        }
      })
    }
  });

  try {
    await proof.verifySignature({
      verifyData: new Uint8Array([1, 2, 3]),
      verificationMethod: {id: 'did:example:issuer#key-1'},
      proof: {proofValue: testCase.proofValue}
    });
    const passed = observed.signatureHex === testCase.expectedSignatureHex;
    results.push({
      id: testCase.id,
      decoded: true,
      passed,
      signatureHex: observed.signatureHex
    });
  } catch(e) {
    const message = e?.message ?? String(e);
    const passed = testCase.expectedError?.test(message) === true;
    results.push({
      id: testCase.id,
      decoded: false,
      passed,
      error: message
    });
  }
}

const passed = results.every(result => result.passed);
const highSResult = await characterizeHighSCounterpart();
const allPassed = passed && highSResult.passed;
console.log(JSON.stringify({
  passed: allPassed,
  results,
  highSResult
}, null, 2));
if(!allPassed) {
  process.exitCode = 1;
}

async function characterizeHighSCounterpart() {
  const key = await crypto.subtle.generateKey(
    {name: 'ECDSA', namedCurve: 'P-256'},
    true,
    ['sign', 'verify']
  );
  const data = new Uint8Array([1, 2, 3]);
  const signature = new Uint8Array(await crypto.subtle.sign(
    {name: 'ECDSA', hash: 'SHA-256'},
    key.privateKey,
    data
  ));
  const s = BigInt('0x' + hex(signature.slice(32)));
  const counterpartS = p256Order - s;
  const counterpart = Buffer.concat([
    Buffer.from(signature.slice(0, 32)),
    bigintTo32Bytes(counterpartS)
  ]);
  const originalVerified = await crypto.subtle.verify(
    {name: 'ECDSA', hash: 'SHA-256'},
    key.publicKey,
    signature,
    data
  );
  const counterpartVerified = await crypto.subtle.verify(
    {name: 'ECDSA', hash: 'SHA-256'},
    key.publicKey,
    counterpart,
    data
  );
  return {
    id: 'p256-high-s-counterpart',
    passed: originalVerified === true && counterpartVerified === true,
    originalSHigh: s > p256Order / 2n,
    counterpartSHigh: counterpartS > p256Order / 2n,
    originalVerified,
    counterpartVerified
  };
}

function bigintTo32Bytes(value) {
  return Buffer.from(value.toString(16).padStart(64, '0'), 'hex');
}

function hex(bytes) {
  return Buffer.from(bytes).toString('hex');
}
