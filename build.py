"""Pack a stage directory (*.json resources + *.sql with header comments) into one FHIR transaction bundle.

SQL header:
    -- id: diabetes-cohort
    -- title: Adults 18-75 with diabetes and a visit in 2026
    -- type: sql-view | sql-query
    -- param: <name> <type>                    (repeatable, sql-query only)
    -- depends-on: <label> <ResourceType/id>      (repeatable)
"""
import base64
import glob
import json
import os
import sys

BASE = "https://example.org/aof"
SOF = "https://sql-on-fhir.org/ig"
PROFILE = {"sql-view": "SQLView", "sql-query": "SQLQuery"}


def library(path):
    meta, deps, params, body = {}, [], [], []
    for line in open(path, encoding="utf-8").read().split("\n"):
        if not body and line.startswith("-- ") and ":" in line:
            key, value = line[3:].split(":", 1)
            if key == "depends-on":
                label, ref = value.split()
                deps.append({"type": "depends-on", "label": label, "resource": f"{BASE}/{ref}"})
            elif key == "param":
                name, kind = value.split()
                params.append({"name": name, "type": kind, "use": "in"})
            else:
                meta[key] = value.strip()
        else:
            body.append(line)
    if "id" not in meta:  # a plain SQL script (e.g. vocabulary.sql), not a Library
        return None
    sql = "\n".join(body).strip() + "\n"
    res = {
        "resourceType": "Library", "id": meta["id"], "url": f"{BASE}/Library/{meta['id']}",
        "name": meta["id"].replace("-", "_"), "title": meta["title"], "status": "active",
        "meta": {"profile": [f"{SOF}/StructureDefinition/{PROFILE[meta['type']]}"]},
        "type": {"coding": [{"system": f"{SOF}/CodeSystem/LibraryTypesCodes", "code": meta["type"]}]},
        "relatedArtifact": deps,
        "content": [{"contentType": "application/sql", "data": base64.b64encode(sql.encode()).decode()}],
    }
    if params:
        res["parameter"] = params
    return res


def main(stage):
    resources = [json.load(open(p, encoding="utf-8")) for p in sorted(glob.glob(f"{stage}/*.json"))]
    resources += [r for r in (library(p) for p in sorted(glob.glob(f"{stage}/*.sql"))) if r]
    entries = [{"resource": r, "request": {"method": "PUT", "url": f"{r['resourceType']}/{r['id']}"}} for r in resources]
    os.makedirs("build", exist_ok=True)
    out = f"build/{stage}.json"
    json.dump({"resourceType": "Bundle", "type": "transaction", "entry": entries}, open(out, "w"), indent=1)
    print(f"{out}: {len(entries)} resources")


if __name__ == "__main__":
    for stage in sys.argv[1:]:
        main(stage.rstrip("/"))
