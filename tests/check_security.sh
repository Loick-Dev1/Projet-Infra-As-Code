#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/config.sh"

if [ "$TARGET_URL" = "http://4.233.87.143/" ]; then
  echo "ERROR: Set TARGET_URL in tests/config.sh or export TARGET_URL environment variable."
  exit 2
fi

echo "Checking security headers on $TARGET_URL"

# Basic HTTP 200 check
status_code=$(curl -s -o /dev/null -w "%{http_code}" -A "$USER_AGENT" --max-time $TIMEOUT -I "$TARGET_URL")
if [ "$status_code" != "200" ]; then
  echo "FAIL: Expected HTTP 200 but got $status_code"
  exit 1
fi

echo "HTTP 200 OK"

# Check for expected header
# Configure the header name and expected value below
HEADER_NAME="X-Frame-Options"
EXPECTED_VALUE="DENY"

header_value=$(curl -s -I -A "$USER_AGENT" --max-time $TIMEOUT "$TARGET_URL" | grep -i "^$HEADER_NAME:" | sed -E 's/^[^:]+:\s*//I' | tr -d '\r') || true

if [ -z "$header_value" ]; then
  echo "FAIL: Header $HEADER_NAME not present"
  exit 1
fi

# If EXPECTED_VALUE is non-empty, verify it matches
if [ -n "$EXPECTED_VALUE" ] && [ "$(echo "$header_value" | tr '[:upper:]' '[:upper:]')" != "$(echo "$EXPECTED_VALUE" | tr '[:upper:]' '[:upper:]')" ]; then
  echo "FAIL: Header $HEADER_NAME value mismatch. Expected: $EXPECTED_VALUE, Got: $header_value"
  exit 1
fi

echo "Security header $HEADER_NAME present and correct: $header_value"
exit 0
