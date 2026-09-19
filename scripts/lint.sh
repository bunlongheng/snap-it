#!/usr/bin/env bash
# Snap It has no third party linter. The gates are the compiler's own
# diagnostics plus the house rules a compiler cannot see.
set -uo pipefail

status=0
kit=$(find Sources/SnapItKit -name '*.swift')
app=$(find Sources/SnapIt -name '*.swift')
tests=$(find Tests -name '*.swift')
all="$kit $app $tests"

# The app and the tests each have their own main.swift, so they are two
# separate compilations and cannot be type checked in one pass.
typecheck() {
  local label="$1"
  shift
  local output
  output=$(swiftc -swift-version 5 -typecheck -framework Cocoa -framework Carbon \
    -framework ServiceManagement "$@" 2>&1 | grep -E 'error:|warning:' || true)
  if [ -n "$output" ]; then
    echo "  $label:"
    echo "$output"
    status=1
  else
    echo "  $label: clean"
  fi
}

report() {
  local label="$1" output="$2"
  if [ -n "$output" ]; then
    echo "$output"
    status=1
  else
    echo "    none"
  fi
}

echo "==> compiler errors and warnings"
typecheck "app" $kit $app
typecheck "tests" $kit $tests

echo "==> long lines (over 120 characters)"
report "long lines" "$(awk 'length > 120 {print FILENAME":"FNR": "length" chars"}' $all || true)"

echo "==> trailing whitespace"
report "trailing whitespace" "$(grep -rn ' $' $all || true)"

echo "==> leftover markers"
report "markers" "$(grep -rnE 'TODO|FIXME|print\(' $all || true)"

exit $status
