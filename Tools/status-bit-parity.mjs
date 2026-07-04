#!/usr/bin/env node

import {spawnSync} from 'node:child_process';
import {
  createList,
  decodeList
} from '../References/cadmv-dlid-verifier-sdk/node_modules/@digitalbazaar/vc-bitstring-status-list/lib/index.js';

const listLength = 72;
const revokedIndexes = [0, 7, 8, 63, 64, 71];
const clearIndexes = [1, 9, 62, 70];
const outOfRangeIndexes = [72];

const list = await createList({length: listLength});
for(const index of revokedIndexes) {
  list.setStatus(index, true);
}
const encodedList = await list.encode();
const decodedList = await decodeList({encodedList});

const cases = [
  ...revokedIndexes.map(index => ({
    id: `status-bit-${index}-revoked`,
    index,
    expectedAvailable: true,
    expectedStatus: true
  })),
  ...clearIndexes.map(index => ({
    id: `status-bit-${index}-clear`,
    index,
    expectedAvailable: true,
    expectedStatus: false
  })),
  ...outOfRangeIndexes.map(index => ({
    id: `status-bit-${index}-out-of-range`,
    index,
    expectedAvailable: false,
    expectedStatus: null
  }))
];

const results = [];
let failed = false;
for(const testCase of cases) {
  const js = jsStatus(testCase.index);
  const swift = runSwiftStatus(testCase.index);
  const failures = [];
  if(js.available !== testCase.expectedAvailable) {
    failures.push('unexpected JS availability');
  }
  if(swift.available !== testCase.expectedAvailable) {
    failures.push('unexpected Swift availability');
  }
  if(js.status !== testCase.expectedStatus) {
    failures.push('unexpected JS status');
  }
  if(swift.status !== testCase.expectedStatus) {
    failures.push('unexpected Swift status');
  }
  if(js.available !== swift.available) {
    failures.push('status availability mismatch');
  }
  if(js.status !== swift.status) {
    failures.push('status bit mismatch');
  }
  const passed = failures.length === 0;
  failed ||= !passed;
  results.push({
    id: testCase.id,
    index: testCase.index,
    jsAvailable: js.available,
    swiftAvailable: swift.available,
    jsStatus: js.status,
    swiftStatus: swift.status,
    passed,
    failures
  });
}

console.log(JSON.stringify({
  comparedFixtureCount: results.length,
  encodedListByteLength: encodedList.length,
  passed: !failed,
  results
}, null, 2));

if(failed) {
  process.exit(1);
}

function jsStatus(index) {
  try {
    return {
      available: true,
      status: decodedList.getStatus(index)
    };
  } catch {
    return {
      available: false,
      status: null
    };
  }
}

function runSwiftStatus(index) {
  const result = spawnSync(
    'swift',
    ['run', 'CADMVVerifierOracle', '--status-bit'],
    {
      input: JSON.stringify({encodedList, index}),
      encoding: 'utf8',
      maxBuffer: 10 * 1024 * 1024
    }
  );
  if(result.status !== 0) {
    throw new Error([
      `swift run CADMVVerifierOracle --status-bit failed with status ${result.status}`,
      result.stdout,
      result.stderr
    ].filter(Boolean).join('\n'));
  }
  return resultFromOracle(JSON.parse(result.stdout).result);
}

function resultFromOracle(result) {
  return {
    available: result.available === true,
    status: result.status ?? null
  };
}
