#!/usr/bin/env bash
#
# Builds WUUT and prints only what went wrong.
#
# Xcode's issue navigator is awkward to copy out of, and a full xcodebuild log is
# thousands of lines of noise. This gives you the error lines and nothing else —
# paste that straight into a conversation, or let an agent read the log file.
#
#   ./scripts/build.sh          build the app for a device
#   ./scripts/build.sh test     build and run the unit tests on a simulator
#
# Full log is always written to build.log regardless.

set -uo pipefail

PROJECT="WUUT.xcodeproj"
SCHEME="WUUT"
LOG="build.log"
MODE="${1:-build}"

if [ ! -d "$PROJECT" ]; then
  echo "No $PROJECT here. Run 'xcodegen generate' first." >&2
  exit 1
fi

if [ "$MODE" = "test" ]; then
  # A simulator, because unit tests don't need the phone and don't need signing.
  DESTINATION="platform=iOS Simulator,name=iPhone 16"
  ACTION="test"
else
  # 'generic/platform=iOS' compiles for device without one being plugged in.
  DESTINATION="generic/platform=iOS"
  ACTION="build"
fi

echo "==> xcodebuild $ACTION ($DESTINATION)"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -destination "$DESTINATION" "$ACTION" > "$LOG" 2>&1
STATUS=$?

echo
if [ $STATUS -eq 0 ]; then
  echo "==> Succeeded."
  if [ "$MODE" = "test" ]; then
    grep -E "Executed [0-9]+ test" "$LOG" | tail -2
  fi
else
  echo "==> Failed. Errors below; full log in $LOG"
  echo
  # Compiler errors, linker errors, and test failures, de-duplicated and in order.
  grep -E "(error:|error :|\*\* .* FAILED \*\*|XCTAssert.* failed)" "$LOG" \
    | sed 's|'"$PWD"'/||' \
    | awk '!seen[$0]++' \
    | head -60
  echo
  echo "(showing up to 60 unique errors — see $LOG for everything)"
fi

exit $STATUS
