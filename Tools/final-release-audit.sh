#!/bin/sh

set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root_dir"

run() {
    printf '\n==> %s\n' "$*"
    "$@"
}

check_security_exceptions() {
    exception_count=$(
        awk '
            /^Security exception: / &&
            $0 != "Security exception: none" &&
            $0 != "Security exception: none | <id>" {
                count += 1
            }
            END { print count + 0 }
        ' Docs/PARITY_STATUS.md
    )

    if [ "$exception_count" -ne 0 ]; then
        printf 'Security exception inventory contains %s non-none record(s).\n' "$exception_count" >&2
        printf 'Each accepted JS/Swift divergence must have an approved security-exception record before release.\n' >&2
        exit 1
    fi
}

check_documented_gaps() {
    gap_count=$(
        node -e "
            const fs = require('fs');
            const manifest = JSON.parse(fs.readFileSync('Tests/CADMVVerifierTests/Fixtures/fixture-manifest.json', 'utf8'));
            const gaps = manifest.fixtures.filter(f => f.storageLevel === 'documented-gap');
            console.log(gaps.length);
        "
    )

    if [ "$gap_count" -ne 0 ]; then
        printf 'Fixture manifest contains %s documented gap(s).\n' "$gap_count" >&2
        printf 'Documented gaps must be converted to committed, generated, or redacted-vector coverage before final release.\n' >&2
        exit 1
    fi
}

run swift build
run swift build -c release
run Tools/swift-test.sh
run swift run CADMVVerifierSelfTest
run Tools/parity-status.sh
run Tools/reference-oracle-smoke.sh
run Tools/replacement-readiness.sh
run node Tools/generate-conformance-report.mjs --check
check_security_exceptions
check_documented_gaps

printf '\nFinal release audit: PASS\n'
