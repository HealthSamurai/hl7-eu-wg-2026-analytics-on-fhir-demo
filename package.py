"""Pack every artifact of the demo into one FHIR package: build/org.example.analytics-on-fhir-<version>.tgz

    python3 package.py

The package holds the ViewDefinitions, the SQLView and SQLQuery Libraries, the ValueSet and the ConceptMaps.
It does not hold the data, the OMOP vocabulary tables (03-omop/vocabulary.sql) or anything Aidbox-specific
(01-2-materialize/).
"""
import glob
import io
import json
import os
import tarfile

from build import BASE, library

NAME = "org.example.analytics-on-fhir"
VERSION = "0.1.0"
STAGES = ["01-1-view-definitions", "02-cohort", "03-omop", "04-ehds"]


def main():
    resources = []
    for stage in STAGES:
        resources += [json.load(open(p, encoding="utf-8")) for p in sorted(glob.glob(f"{stage}/*.json"))]
        resources += [r for r in (library(p) for p in sorted(glob.glob(f"{stage}/*.sql"))) if r]
    files = {f"{r['resourceType']}-{r['id']}.json": r for r in resources}
    files["package.json"] = {
        "name": NAME, "version": VERSION, "type": "fhir.ig", "canonical": BASE, "license": "BSD-3-Clause",
        "description": "Analytics on FHIR demo: flat views, a diabetes cohort, a mapping to OMOP and rules for secondary use",
        "fhirVersions": ["4.0.1"], "dependencies": {"hl7.fhir.r4.core": "4.0.1"},
    }
    files[".index.json"] = {"index-version": 1, "files": [
        {"filename": name, "resourceType": r["resourceType"], "id": r["id"], "url": r.get("url")}
        for name, r in files.items() if name not in ("package.json", ".index.json")]}
    os.makedirs("build", exist_ok=True)
    out = f"build/{NAME}-{VERSION}.tgz"
    with tarfile.open(out, "w:gz") as tgz:
        for name, content in sorted(files.items()):
            data = json.dumps(content, indent=1).encode()
            info = tarfile.TarInfo(f"package/{name}")
            info.size = len(data)
            tgz.addfile(info, io.BytesIO(data))
    kinds = {}
    for r in resources:
        kind = r["resourceType"]
        if kind == "Library":
            kind = r["type"]["coding"][0]["code"]
        kinds[kind] = kinds.get(kind, 0) + 1
    print(f"{out}: {len(resources)} resources", kinds)


if __name__ == "__main__":
    main()
