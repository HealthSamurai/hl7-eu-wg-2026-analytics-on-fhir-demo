#!/usr/bin/env bash
# Return Aidbox to an empty state without touching the license:
#   - delete every ViewDefinition, Library and AidboxMaterialization, and the ValueSet / ConceptMap resources of this demo
#   - truncate the clinical tables, drop the schemas sof (materialized views) and omop (vocabulary)
set -euo pipefail
cd "$(dirname "$0")"
AIDBOX=${AIDBOX_URL:-http://localhost:8080}
SECRET=${AIDBOX_SECRET:-$(sed -n 's/.*BOX_ROOT_CLIENT_SECRET: *//p' aidbox/docker-compose.yaml)}

ids() { curl -s -u "root:$SECRET" "$AIDBOX/fhir/$1?_count=500&_elements=id" | python3 -c '
import json, sys
for e in json.load(sys.stdin).get("entry", []): print(e["resource"]["resourceType"] + "/" + e["resource"]["id"])'; }
ours() { python3 -c '
import glob, json
for p in glob.glob("0[1-9]-*/*.json"):
    r = json.load(open(p))
    if r["resourceType"] in ("ValueSet", "ConceptMap"): print(r["resourceType"] + "/" + r["id"])'; }

for ref in $(ids AidboxMaterialization) $(ids Library) $(ids ViewDefinition) $(ours); do
  echo "DELETE $ref $(curl -s -o /dev/null -w '%{http_code}' -u "root:$SECRET" -X DELETE "$AIDBOX/fhir/$ref")"
done

SQL='truncate patient, patient_history, organization, organization_history, encounter, encounter_history, condition, condition_history, observation, observation_history, consent, consent_history; drop schema if exists sof cascade; drop schema if exists omop cascade'
curl -s -u "root:$SECRET" -X POST "$AIDBOX/\$psql" -H 'content-type: application/json' -d "{\"query\":\"$SQL\"}" | grep -o '"status":"[a-z]*"'
