#!/bin/sh

set -eu

status_file="Docs/PARITY_STATUS.md"

if [ ! -f "$status_file" ]; then
    echo "Parity status: missing $status_file"
    exit 1
fi

blocking_count=$(grep -c '^Blocking: yes$' "$status_file" || true)

echo "Parity status report"
echo "Known blocking parity records: $blocking_count"

if [ "$blocking_count" -gt 0 ]; then
    awk '
        /^Fixture ID:/ { fixture=$0 }
        /^First divergence stage:/ { divergence=$0 }
        /^Blocking: yes$/ {
            print "- " fixture
            print "  " divergence
        }
    ' "$status_file"
    exit 1
fi

echo "See $status_file for details."
