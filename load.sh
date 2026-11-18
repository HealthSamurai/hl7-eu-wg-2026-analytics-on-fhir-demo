#!/usr/bin/env bash
# Load the demo into Aidbox, one directory at a time. Every entry is a PUT, so each step can be re-run.
#   ./load.sh 00-population/         the synthetic population: 12 bundles + hand-made extra cases
#   ./load.sh 01-1-view-definitions/ demo 1: ViewDefinitions
#   ./load.sh 01-2-materialize/      demo 1: the views as database views in the schema sof (Aidbox feature)
#   ./load.sh 02-cohort/             demo 2: ValueSet, data quality checks, cohort, follow-up queries
#   ./load.sh 03-omop/               demo 3: OMOP vocabulary subset, ConceptMaps, mapping and OMOP views
#   ./load.sh 04-ehds/               demo 4: opt-outs, a minimised research extract, an aggregate answer
#   ./load.sh all                    everything, in this order
set -euo pipefail
cd "$(dirname "$0")"
AIDBOX=${AIDBOX_URL:-http://localhost:8080}
SECRET=${AIDBOX_SECRET:-$(sed -n 's/.*BOX_ROOT_CLIENT_SECRET: *//p' aidbox/docker-compose.yaml)}
JSON='content-type: application/json'

post() {  # post <file> <path>
  local code
  code=$(curl -s -o /tmp/aof-load.out -w '%{http_code}' -u "root:$SECRET" -X POST "$AIDBOX$2" -H "$JSON" -d @"$1")
  if [ "${code:0:1}" != 2 ]; then echo "FAILED $1 -> HTTP $code"; head -c 600 /tmp/aof-load.out; echo; exit 1; fi
}
count() { curl -s -u "root:$SECRET" "$AIDBOX/fhir/$1?_count=0&_total=accurate" | sed -n 's/.*"total":\([0-9]*\).*/\1/p'; }
run() {  # run <library id>
  curl -s -u "root:$SECRET" -X POST "$AIDBOX/fhir/Library/$1/\$sqlquery-run" -H "$JSON" \
    -d '{"resourceType":"Parameters","parameter":[{"name":"_format","valueCode":"csv"}]}'
}

load_population() {
  for f in 00-population/bundle-*.json; do post "$f" /fhir; echo "loaded $f"; done
  for t in Patient Organization Encounter Condition Observation Consent; do echo "$t: $(count $t)"; done
}
load_views() {
  python3 build.py 01-1-view-definitions
  post build/01-1-view-definitions.json /fhir
}
materialize() {  # materialize <AidboxMaterialization file>: create the resource, run $materialize, wait for it
  # Aidbox, not SQL on FHIR: AidboxMaterialization says where a view lives in the database;
  # $materialize on it (async only) builds it
  local f=$1 id name status code
  id=$(sed -n 's/.*"id": *"\([^"]*\)".*/\1/p' "$f" | head -1)
  name=$(basename "$f" .json)
  code=$(curl -s -o /tmp/aof-load.out -w '%{http_code}' -u "root:$SECRET" -X PUT "$AIDBOX/fhir/AidboxMaterialization/$id" -H "$JSON" -d @"$f")
  if [ "${code:0:1}" != 2 ]; then echo "FAILED $f -> HTTP $code"; head -c 600 /tmp/aof-load.out; echo; exit 1; fi
  echo '{"resourceType":"Parameters","parameter":[]}' > /tmp/aof-params.json
  status=$(curl -s -o /dev/null -D - -u "root:$SECRET" -X POST "$AIDBOX/fhir/AidboxMaterialization/$id/\$materialize" \
    -H "$JSON" -H 'Prefer: respond-async' -d @/tmp/aof-params.json | sed -n 's/^[Cc]ontent-[Ll]ocation: *//p' | tr -d '\r')
  if [ -z "$status" ]; then echo "FAILED to start \$materialize for $id"; exit 1; fi
  for _ in $(seq 1 60); do
    code=$(curl -s -o /tmp/aof-load.out -w '%{http_code}' -u "root:$SECRET" "$AIDBOX$status")
    [ "$code" = 202 ] || break
    sleep 0.5
  done
  if [ "$code" != 200 ] || ! grep -q 'completed successfully' /tmp/aof-load.out; then
    echo "FAILED \$materialize for $id -> HTTP $code"; head -c 600 /tmp/aof-load.out; echo; exit 1
  fi
  echo "sof.$name"
}
load_materialize() {
  for f in 01-2-materialize/*.json; do materialize "$f"; done
}
psql() {  # psql <file.sql>: run a SQL script in the Aidbox database
  python3 -c 'import json,sys; print(json.dumps({"query": open(sys.argv[1]).read()}))' "$1" > /tmp/aof-sql.json
  post /tmp/aof-sql.json '/$psql'
  if grep -q '"status":"error"' /tmp/aof-load.out; then echo "FAILED $1"; head -c 600 /tmp/aof-load.out; echo; exit 1; fi
}

load_cohort() {
  python3 build.py 02-cohort
  post build/02-cohort.json /fhir
  materialize 02-cohort/materialize/vs_diabetes.json  # the value set as a database view, through a SQLView
  run dq-summary
  run summary
}

load_omop() {
  psql 03-omop/vocabulary.sql; echo "omop.concept, omop.concept_relationship"
  python3 build.py 03-omop
  post build/03-omop.json /fhir
  run naive-vs-explicit
  run omop-follow-up
}

load_ehds() {
  python3 build.py 04-ehds
  post build/04-ehds.json /fhir
  run primary-vs-secondary
}

arg=${1:-}
case "${arg%/}" in
  00-population)         load_population ;;
  01-1-view-definitions) load_views ;;
  01-2-materialize)      load_materialize ;;
  02-cohort)             load_cohort ;;
  03-omop)               load_omop ;;
  04-ehds)               load_ehds ;;
  all) load_population; load_views; load_materialize; load_cohort; load_omop; load_ehds ;;
  *) sed -n '2,9p' "$0"; exit 1 ;;
esac
