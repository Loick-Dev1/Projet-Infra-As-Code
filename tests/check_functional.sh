#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/config.sh"

if [ "$TARGET_URL" = "http://REPLACE_WITH_VM_IP_OR_DNS" ]; then
  echo "ERROR: Set TARGET_URL in tests/config.sh or export TARGET_URL environment variable."
  exit 2
fi

echo "Checking functional requirements against $TARGET_URL"

# Check HTTP status 200
status_code=$(curl -s -o /dev/null -w "%{http_code}" -A "$USER_AGENT" --max-time $TIMEOUT "$TARGET_URL")
if [ "$status_code" != "200" ]; then
  echo "FAIL: Expected HTTP 200 but got $status_code"
  exit 1
fi

echo "HTTP 200 OK"

# Check expected content
expected_string="Hello Infrastructure as Code"
body=$(curl -s -A "$USER_AGENT" --max-time $TIMEOUT "$TARGET_URL")
if ! echo "$body" | grep -q "$expected_string"; then
  echo "FAIL: Expected page to contain: $expected_string"
  exit 1
fi

echo "Content check passed"
exit 0
