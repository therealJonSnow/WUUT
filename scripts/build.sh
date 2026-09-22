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
  #
  # Resolved by id rather than pinned by name. A bare 'name=iPhone 16' is matched
  # against OS:latest, so it stops resolving the day Xcode ships a runtime with no
  # iPhone 16 on it — which Xcode 27 did, its newest simulators being the 17 and 18.
  # Prefer a booted device if there is one, else the last iPhone the scheme lists,
  # which is the newest runtime. Override with WUUT_SIM_ID if you want a specific one.
  DESTINATION_ID="${WUUT_SIM_ID:-}"
  if [ -z "$DESTINATION_ID" ]; then
    DESTINATION_ID=$(xcrun simctl list devices available 2>/dev/null \
      | grep -E "^[[:space:]]+iPhone" | grep "(Booted)" | head -1 \
      | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  fi
  if [ -z "$DESTINATION_ID" ]; then
    DESTINATION_ID=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showdestinations 2>/dev/null \
      | grep "platform:iOS Simulator" | grep "name:iPhone" \
      | sed -E 's/.*id:([0-9A-F-]{36}).*/\1/' | tail -1)
  fi
  if [ -z "$DESTINATION_ID" ]; then
    echo "No iOS simulator available. Open Xcode and install a simulator runtime." >&2
    exit 1
  fi
  DESTINATION="id=$DESTINATION_ID"
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
