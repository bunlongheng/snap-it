#!/usr/bin/env bash
# Snap It has no third party linter. The gates are the compiler's own warnings
# plus a check for the house style rules that a compiler cannot see.
set -uo pipefail

status=0
sources=$(find Sources Tests -name '*.swift')

echo "==> compiler warnings"
warnings=$(swiftc -swift-version 5 -typecheck -framework Cocoa -framework Carbon \
  -framework ServiceManagement $sources 2>&1 | grep -E 'warning:' || true)
if [ -n "$warnings" ]; then
  echo "$warnings"
  status=1
else
  echo "    none"
fi

echo "==> long lines (over 120 characters)"
long=$(awk 'length > 120 {print FILENAME":"FNR": "length" chars"}' $sources || true)
if [ -n "$long" ]; then
  echo "$long"
  status=1
else
  echo "    none"
fi

echo "==> trailing whitespace"
trailing=$(grep -rn ' $' $sources || true)
if [ -n "$trailing" ]; then
  echo "$trailing"
  status=1
else
  echo "    none"
fi

echo "==> leftover markers"
markers=$(grep -rnE 'TODO|FIXME|print\(' $sources || true)
if [ -n "$markers" ]; then
  echo "$markers"
  status=1
else
  echo "    none"
fi

exit $status
