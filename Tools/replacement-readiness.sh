#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

failures=0

report_failure() {
  failures=$((failures + 1))
  printf 'RELEASE BLOCKER: %s\n' "$1"
}

if rg -n \
  'SupportedProfileJSONLDCanonicalizationEngine\.shared' \
  Sources/CADMVVerifier \
  >/tmp/cadmv-replacement-engine-refs.txt; then
  report_failure "Public verifier paths still default to SupportedProfileJSONLDCanonicalizationEngine.shared."
  cat /tmp/cadmv-replacement-engine-refs.txt
fi

if rg -n \
  'Final completion still requires|not yet a final proof|Remaining Phase 4 gates|Remaining Scope' \
  Docs Tools/generate-conformance-report.mjs \
  >/tmp/cadmv-replacement-doc-refs.txt; then
  report_failure "Docs and generated reports still carry final replacement caveats."
  cat /tmp/cadmv-replacement-doc-refs.txt
fi

if [ "$failures" -gt 0 ]; then
  cat <<'EOF'

Replacement readiness: FAIL

This is expected until the final native or native-library-backed JSON-LD/RDF
canonicalization engine is the public default and the release-blocking caveats
have been removed or narrowed to intentional policy limits.
EOF
  exit 1
fi

echo "Replacement readiness: PASS"
