#!/usr/bin/env bash
# Run something on Aidbox and print the result as CSV.
#   ./query.sh ViewDefinition/<id> [limit]   run a ViewDefinition ($run), 10 rows by default
#   ./query.sh Library/<id> [name=value ...] run a SQLView or SQLQuery ($sqlquery-run), with parameters if any
#   ./query.sh sql "<select ...>"            run plain SQL in the Aidbox database
#   ./query.sh -v | --verbose ...            also print the request, ready to paste into the Aidbox REST console
#   ./query.sh -n | --dry-run ...            print the request and do not run it
# The request and the labels go to stderr, the result to stdout, so the result can be piped.
set -euo pipefail
cd "$(dirname "$0")"
AIDBOX=${AIDBOX_URL:-http://localhost:8080}
SECRET=${AIDBOX_SECRET:-$(sed -n 's/.*BOX_ROOT_CLIENT_SECRET: *//p' aidbox/docker-compose.yaml)}

DRY_RUN=
VERBOSE=
ARGS=()
for a in "$@"; do
  case "$a" in
    -n|--dry-run) DRY_RUN=1 ;;
    -v|--verbose) VERBOSE=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
set -- "${ARGS[@]:-}"

params() {  # params <name> <value[x] key> <json value> ...  ->  FHIR Parameters
  python3 -c '
import json, sys
a = sys.argv[1:]
print(json.dumps({"resourceType": "Parameters",
                  "parameter": [{"name": a[i], a[i + 1]: json.loads(a[i + 2])} for i in range(0, len(a), 3)]}, indent=2))' "$@"
}

ACCEPT=
case "${1:-}" in
  ViewDefinition/*)
    URL="/fhir/$1/\$run"
    ACCEPT='text/csv'
    BODY=$(params _format valueCode '"csv"' _limit valueInteger "${2:-10}") ;;
  Library/*)
    URL="/fhir/$1/\$sqlquery-run"
    BODY=$(python3 -c '
import json, sys
body = {"resourceType": "Parameters", "parameter": [{"name": "_format", "valueCode": "csv"}]}
values = [a.split("=", 1) for a in sys.argv[1:] if "=" in a]
if values:  # query parameters travel as a nested Parameters resource, bound by name
    body["parameter"].append({"name": "parameters", "resource": {
        "resourceType": "Parameters", "parameter": [{"name": k, "valueString": v} for k, v in values]}})
print(json.dumps(body, indent=2))' "${@:2}") ;;
  sql)
    URL='/$psql'
    BODY=$(python3 -c 'import json,sys; print(json.dumps({"query": sys.argv[1]}, indent=2))' "$2") ;;
  *) sed -n '2,8p' "$0"; exit 1 ;;
esac

if [ -n "$VERBOSE" ] || [ -n "$DRY_RUN" ]; then {
  echo "Request:"
  echo
  echo "POST $URL"
  echo "content-type: application/json"
  if [ -n "$ACCEPT" ]; then echo "accept: $ACCEPT"; fi
  echo
  echo "$BODY"
  echo
} >&2; fi
if [ -n "$DRY_RUN" ]; then exit 0; fi
if [ -n "$VERBOSE" ]; then { echo "Response:"; echo; } >&2; fi

response() {
  if [ -n "$ACCEPT" ]; then
    curl -s -u "root:$SECRET" -X POST "$AIDBOX$URL" -H 'content-type: application/json' -H "accept: $ACCEPT" -d "$BODY"
  else
    curl -s -u "root:$SECRET" -X POST "$AIDBOX$URL" -H 'content-type: application/json' -d "$BODY"
  fi
}
if [ "$1" = sql ]; then
  response | python3 -c '
import csv, json, sys
body = json.load(sys.stdin)
res = (body.get("result") or [{}])[0]
if not isinstance(res.get("data"), list):
    sys.exit(json.dumps(body)[:600])
if res["data"]:
    w = csv.DictWriter(sys.stdout, fieldnames=list(res["data"][0]))
    w.writeheader(); w.writerows(res["data"])'
else
  response
fi
