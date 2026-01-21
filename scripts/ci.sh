#!/usr/bin/env bash
set -euo pipefail

SCHEME=${SCHEME:-SoftDraft}
DESTINATION=${DESTINATION:-"platform=macOS,arch=arm64"}
DEBUG_CONFIGURATION=${DEBUG_CONFIGURATION:-Debug}
ARCHIVE_PATH=${ARCHIVE_PATH:-build/SoftDraft.xcarchive}
CI_ARCHIVE=${CI_ARCHIVE:-false}

run() {
  echo "==> $*"
  "$@"
}

run xcodebuild -scheme "$SCHEME" -configuration "$DEBUG_CONFIGURATION" -destination "$DESTINATION" build
run xcodebuild -scheme "$SCHEME" -destination "$DESTINATION" test

if [[ "$CI_ARCHIVE" == "true" ]]; then
  run xcodebuild -scheme "$SCHEME" -configuration Release -archivePath "$ARCHIVE_PATH" archive
fi
