#!/bin/sh

set -eu

if [ -z "${DEVELOPER_DIR:-}" ] &&
   [ -d /Applications/Xcode.app/Contents/Developer ] &&
   [ "$(xcode-select -p 2>/dev/null || true)" = "/Library/Developer/CommandLineTools" ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

exec swift test "$@"
