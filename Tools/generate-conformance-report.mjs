#!/usr/bin/env node

import {readFileSync, writeFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';

const outputPath = new URL('../Docs/CONFORMANCE_REPORT.md', import.meta.url);
const sdkPackage = JSON.parse(readFileSync(
  new URL('../References/cadmv-dlid-verifier-sdk/package.json', import.meta.url),
  'utf8'
));

const jsonGates = [
  {
    id: 'official-uat-fixtures',
    label: 'Official UAT Fixture Parity',
    command: process.execPath,
    args: ['Tools/parity-compare.mjs']
  },
  {
    id: 'generated-signatures',
    label: 'Generated Signature Parity',
    command: process.execPath,
    args: ['Tools/generated-signature-parity.mjs']
  },
  {
    id: 'mutation-parity',
    label: 'Deterministic Mutation Parity',
    command: process.execPath,
    args: ['Tools/mutation-parity.mjs']
  },
  {
    id: 'status-list',
    label: 'Status-List Verify-Data And N-Quads Parity',
    command: process.execPath,
    args: ['Tools/status-list-parity.mjs']
  },
  {
    id: 'status-bit',
    label: 'Status Bit Boundary Parity',
    command: process.execPath,
    args: ['Tools/status-bit-parity.mjs']
  },
  {
    id: 'status-list-extension-matrix',
    label: 'Status-List Extension Matrix Verify-Data And N-Quads Parity',
    command: process.execPath,
    args: ['Tools/status-list-extension-matrix-parity.mjs']
  },
  {
    id: 'generic-vcb-jsonld',
    label: 'Generic VCB JSON-LD Extension N-Quads Parity',
    command: process.execPath,
    args: ['Tools/generic-jsonld-extension-parity.mjs']
  },
  {
    id: 'generic-proof-jsonld',
    label: 'Generic Proof JSON-LD Extension N-Quads Parity',
    command: process.execPath,
    args: ['Tools/generic-proof-extension-parity.mjs']
  },
  {
    id: 'jsonld-extension-matrix',
    label: 'JSON-LD Extension Matrix N-Quads Parity',
    command: process.execPath,
    args: ['Tools/jsonld-extension-matrix-parity.mjs']
  },
  {
    id: 'jsonld-behavior-characterization',
    label: 'JSON-LD 1.1 Behavior Characterization',
    command: process.execPath,
    args: ['Tools/jsonld-behavior-characterization.mjs']
  },
  {
    id: 'canonicalization-engine-differential',
    label: 'Canonicalization Engine Differential',
    command: process.execPath,
    args: ['Tools/canonicalization-engine-differential.mjs']
  }
];

const testGates = [
  {
    id: 'w3c-rdfc-subset',
    label: 'W3C RDFC-1.0 Conformance Subset',
    command: 'Tools/swift-test.sh',
    args: ['--filter', 'RDFDatasetCanonicalizerTests/testW3CRDFC10ConformanceSubset']
  },
  {
    id: 'w3c-rdfc-issued-map-subset',
    label: 'W3C RDFC-1.0 Issued-Identifier Map Subset',
    command: 'Tools/swift-test.sh',
    args: ['--filter', 'RDFDatasetCanonicalizerTests/testW3CRDFC10IssuedIdentifierMapSubset']
  },
  {
    id: 'w3c-rdfc-negative-clique',
    label: 'W3C RDFC-1.0 Negative Clique Fail-Closed Coverage',
    command: 'Tools/swift-test.sh',
    args: ['--filter', 'RDFDatasetCanonicalizerTests/testW3CRDFC10NegativeCliqueGraphFailsClosed']
  }
];

const gateResults = [];
for(const gate of jsonGates) {
  const started = Date.now();
  const json = runJSON(gate.command, gate.args);
  gateResults.push({
    id: gate.id,
    label: gate.label,
    command: shellCommand(gate.command, gate.args),
    durationMs: Date.now() - started,
    passed: json.passed === true,
    comparedFixtureCount: json.comparedFixtureCount ??
      json.characterizedCaseCount ?? json.results?.length ?? 0,
    fixtureIDs: (json.results ?? []).map(result => result.id),
    failures: collectFailures(json.results ?? []),
    notes: notesForGate(gate.id, json)
  });
}

for(const gate of testGates) {
  const started = Date.now();
  runCommand(gate.command, gate.args);
  gateResults.push({
    id: gate.id,
    label: gate.label,
    command: shellCommand(gate.command, gate.args),
    durationMs: Date.now() - started,
    passed: true,
    comparedFixtureCount: 1,
    fixtureIDs: [gate.id],
    failures: [],
    notes: []
  });
}

const report = renderReport({
  sdkPackage,
  generatedAt: new Date().toISOString(),
  gitRevision: runText('git', ['rev-parse', '--short', 'HEAD']).trim(),
  gates: gateResults
});
writeFileSync(outputPath, report);
console.log(`Wrote ${outputPath.pathname}`);

function runJSON(command, args) {
  const result = runCommand(command, args);
  return JSON.parse(result.stdout);
}

function runText(command, args) {
  return runCommand(command, args).stdout;
}

function runCommand(command, args) {
  const result = spawnSync(command, args, {
    encoding: 'utf8',
    maxBuffer: 50 * 1024 * 1024
  });
  if(result.status !== 0) {
    throw new Error([
      `${shellCommand(command, args)} failed with status ${result.status}`,
      result.stdout,
      result.stderr
    ].filter(Boolean).join('\n'));
  }
  return result;
}

function shellCommand(command, args) {
  const displayCommand = command === process.execPath ? 'node' : command;
  return [displayCommand, ...args].join(' ');
}

function collectFailures(results) {
  return results.flatMap(result =>
    (result.failures ?? []).map(failure => `${result.id}: ${failure}`));
}

function notesForGate(id, json) {
  if(id === 'status-list-extension-matrix') {
    return (json.results ?? []).map(result =>
      `${result.id}: document ${shortPair(
        result.jsDocumentCanonicalNQuadsSHA256,
        result.swiftDocumentCanonicalNQuadsSHA256
      )}; proof ${shortPair(
        result.jsProofCanonicalNQuadsSHA256,
        result.swiftProofCanonicalNQuadsSHA256
      )}`);
  }
  if(id === 'jsonld-extension-matrix') {
    return (json.results ?? []).map(result =>
      `${result.id}: ${result.profile}; ${shortPair(
        result.jsCanonicalNQuadsSHA256,
        result.swiftCanonicalNQuadsSHA256
      )}`);
  }
  if(id === 'jsonld-behavior-characterization') {
    return (json.results ?? []).map(result =>
      `${result.id}: ${result.classification}; JS accepted=${result.jsAccepted}; Swift accepted=${result.swiftAccepted}`);
  }
  if(id === 'canonicalization-engine-differential') {
    return (json.results ?? []).map(result => {
      if(result.kind === 'rejection') {
        return `${result.id}: ${result.profile}; JS accepted=${result.jsAccepted}; Swift production accepted=${result.swiftProductionAccepted}; Swift supported-profile accepted=${result.swiftSupportedProfileAccepted}`;
      }
      const engineScope = result.supportedProfileComparison ?
        '; production/supported-profile compared' :
        '; production only';
      return `${result.id}: ${result.profile}; ${shortPair(
        result.jsCanonicalNQuadsSHA256,
        result.swiftProductionCanonicalNQuadsSHA256
      )}${engineScope}`;
    });
  }
  if(id !== 'status-list') {
    return [];
  }
  return (json.results ?? []).map(result =>
    `${result.id}: document ${shortPair(
      result.jsDocumentCanonicalNQuadsSHA256,
      result.swiftDocumentCanonicalNQuadsSHA256
    )}; proof ${shortPair(
      result.jsProofCanonicalNQuadsSHA256,
      result.swiftProofCanonicalNQuadsSHA256
    )}`);
}

function shortPair(jsHash, swiftHash) {
  if(!jsHash || !swiftHash) {
    return 'N-Quads fingerprints unavailable';
  }
  return jsHash === swiftHash ?
    `N-Quads SHA-256 ${jsHash}` :
    `JS ${jsHash}, Swift ${swiftHash}`;
}

function renderReport({sdkPackage, generatedAt, gitRevision, gates}) {
  const allPassed = gates.every(gate => gate.passed);
  const lines = [
    '# Conformance Report',
    '',
    `Generated: ${generatedAt}`,
    `Repository revision: \`${gitRevision}\``,
    `Reference SDK: \`${sdkPackage.name}@${sdkPackage.version}\``,
    '',
    'This report is generated from committed non-PII fixtures and synthetic cases. It does not include raw PDF417 payloads, decoded identity fields, or real private scan data.',
    '',
    `Overall result: ${allPassed ? 'PASS' : 'FAIL'}`,
    '',
    '## Gate Summary',
    '',
    '| Gate | Command | Cases | Result |',
    '| --- | --- | ---: | --- |'
  ];
  for(const gate of gates) {
    lines.push(`| ${gate.label} | \`${gate.command}\` | ${gate.comparedFixtureCount} | ${gate.passed ? 'PASS' : 'FAIL'} |`);
  }
  lines.push('', '## Covered Cases', '');
  for(const gate of gates) {
    lines.push(`### ${gate.label}`, '');
    lines.push(`- Result: ${gate.passed ? 'PASS' : 'FAIL'}`);
    lines.push(`- Compared cases: ${gate.comparedFixtureCount}`);
    lines.push(`- Duration: ${gate.durationMs} ms`);
    lines.push('- Case IDs:');
    for(const id of gate.fixtureIDs) {
      lines.push(`  - \`${id}\``);
    }
    if(gate.notes.length > 0) {
      lines.push('- Notes:');
      for(const note of gate.notes) {
        lines.push(`  - ${note}`);
      }
    }
    if(gate.failures.length > 0) {
      lines.push('- Failures:');
      for(const failure of gate.failures) {
        lines.push(`  - ${failure}`);
      }
    }
    lines.push('');
  }
  lines.push('## Remaining Scope', '');
  lines.push('- This report covers the selected official SDK baseline fixtures, generated non-PII fixtures, supported status-list parity fixtures, generic extension parity fixtures, JSON-LD behavior characterization cases, and the current W3C RDFC subset tests.');
  lines.push('- It is not yet a final proof that handwritten canonical N-Quads have been removed from public verification.');
  lines.push('- Final completion still requires the standards-grade or native-library-backed canonicalization engine described in `Docs/LONG_TERM_JS_PARITY_PLAN.md`.');
  return `${lines.join('\n')}\n`;
}
