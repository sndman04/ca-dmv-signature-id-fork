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

run swift build
run swift build -c release
run Tools/swift-test.sh
run swift run CADMVVerifierSelfTest
run Tools/parity-status.sh
run Tools/reference-oracle-smoke.sh
run Tools/replacement-readiness.sh
run node Tools/generate-conformance-report.mjs --check
check_security_exceptions

printf '\nFinal release audit: PASS\n'
