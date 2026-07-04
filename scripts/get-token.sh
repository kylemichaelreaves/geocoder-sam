#!/usr/bin/env bash
#
# Fetch a JWT from resourceQuerier's login endpoint, for testing the geocoder API.
#
# Credentials are read from environment variables so they are NEVER committed.
# Set them in your gitignored .envrc (see .envrc.example) or export them ad hoc:
#
#   RQ_LOGIN_EMAIL      (required)  login email
#   RQ_LOGIN_PASSWORD   (required)  login password
#   RQ_API_BASE_URL     (optional)  defaults to the deployed resourceQuerier API
#
# Usage:
#   ./scripts/get-token.sh          # print the token (for `TOKEN=$(./scripts/get-token.sh)`)
#   ./scripts/get-token.sh --copy   # copy to clipboard (macOS), print nothing sensitive
#
set -euo pipefail

: "${RQ_LOGIN_EMAIL:?Set RQ_LOGIN_EMAIL (see .envrc.example)}"
: "${RQ_LOGIN_PASSWORD:?Set RQ_LOGIN_PASSWORD (see .envrc.example)}"
BASE="${RQ_API_BASE_URL:-https://a4j9exec83.execute-api.us-east-1.amazonaws.com/Prod}"

# Build the JSON body with node so the credentials are safely encoded (handles
# quotes/special chars) and never interpolated into the shell command line.
body="$(node -e 'process.stdout.write(JSON.stringify({email:process.env.RQ_LOGIN_EMAIL,password:process.env.RQ_LOGIN_PASSWORD}))')"

token="$(curl -s -X POST "$BASE/api/v1/login" \
  -H 'Content-Type: application/json' \
  --data-binary "$body" \
  | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(String(JSON.parse(s).token||""))}catch(e){}})')"

if [ -z "$token" ]; then
  echo "Login failed — check RQ_LOGIN_EMAIL / RQ_LOGIN_PASSWORD / RQ_API_BASE_URL" >&2
  exit 1
fi

if [ "${1:-}" = "--copy" ]; then
  printf '%s' "$token" | pbcopy && echo "JWT copied to clipboard"
else
  printf '%s\n' "$token"
fi
