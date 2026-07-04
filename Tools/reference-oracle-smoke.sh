#!/bin/sh

set -eu

node_bin="${NODE:-node}"
reference_dir="References/cadmv-dlid-verifier-sdk"

if ! command -v "$node_bin" >/dev/null 2>&1; then
    echo "Reference oracle smoke: skipped; node is not available."
    exit 0
fi

if [ ! -d "$reference_dir/node_modules" ]; then
    echo "Reference oracle smoke: skipped; reference SDK dependencies are not installed."
    echo "Install them from $reference_dir before running full JS parity checks."
    exit 0
fi

"$node_bin" Tools/reference-runner.mjs >/dev/null
printf 'ANSI' | "$node_bin" Tools/reference-runner.mjs --stdin --mode=prod >/dev/null
"$node_bin" Tools/parity-compare.mjs >/dev/null
"$node_bin" Tools/status-list-parity.mjs >/dev/null
"$node_bin" Tools/status-list-extension-matrix-parity.mjs >/dev/null
"$node_bin" Tools/cborld-unknown-field-characterization.mjs >/dev/null
"$node_bin" Tools/signature-policy-characterization.mjs >/dev/null
"$node_bin" Tools/generated-signature-parity.mjs >/dev/null
"$node_bin" Tools/mutation-parity.mjs >/dev/null
"$node_bin" Tools/generic-jsonld-extension-parity.mjs >/dev/null
"$node_bin" Tools/generic-proof-extension-parity.mjs >/dev/null
"$node_bin" Tools/jsonld-extension-matrix-parity.mjs >/dev/null
"$node_bin" Tools/jsonld-behavior-characterization.mjs >/dev/null
"$node_bin" Tools/canonicalization-engine-differential.mjs >/dev/null

echo "Reference oracle smoke: passed."
