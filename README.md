# Analytics on FHIR: SQL on FHIR demo

Four hands-on demos that take production-like FHIR data to flat tables, to a cohort and a call list,
to an OMOP dataset, and finally to an extract that follows the rules of secondary use. Everything is a FHIR resource (ViewDefinition, Library,
ValueSet, ConceptMap) loaded into a FHIR server and executed with the SQL on FHIR operations.

Materials of the session **"Analytics on FHIR: progress of the SQL on FHIR specification, FHIR to OMOP subproject"**
by Aleksandr Penskoi (Health Samurai), HL7 Europe Working Group meeting, 19 November 2026.
Slides: <https://www.health-samurai.io/presentations/hl7-eu-wg-2026-analytics-on-fhir> ·
agenda and links: <https://www.health-samurai.io/go/af4na2>

## Table of contents

- [Requirements](#requirements)
- [Repository layout](#repository-layout)
- [Setup](#setup)
- [Demo 1. ViewDefinition in action](#demo-1-viewdefinition-in-action)
- [Demo 2. SQLView, SQLQuery and terminology](#demo-2-sqlview-sqlquery-and-terminology)
- [Demo 3. OMOP mapping in SQLViews](#demo-3-omop-mapping-in-sqlviews)
- [Demo 4. Secondary-use rules as views](#demo-4-secondary-use-rules-as-views)
- [The whole demo as one FHIR package](#the-whole-demo-as-one-fhir-package)
- [Start over](#start-over)
- [Things to know](#things-to-know)
- [Links](#links)
- [License](#license)

## Requirements

| What                           | Why                                                      |
|--------------------------------|----------------------------------------------------------|
| Docker with Compose v2         | runs Aidbox and PostgreSQL                               |
| A free Aidbox account          | the license is activated in the browser on first start   |
| `git`                          | clones this repository                                   |
| `bash`, `curl`                 | the helper scripts                                       |
| Python 3.8 or newer            | packs SQL files into FHIR bundles; standard library only |
| Port 8080 free, about 2 GB RAM | Aidbox listens on `localhost:8080`                       |
| Internet access                | to pull the images and to activate the license           |

Tested on 19 November 2026 with Aidbox `edge`, build `791d207dcc` (built 10 November 2026).

## Repository layout

<details>
<summary>Directories, scripts and the <code>.sql</code> file convention</summary>

| Path                     | What                                                                |
|--------------------------|---------------------------------------------------------------------|
| `00-population/`         | synthetic population: `gen.py` (seed 2026) and its bundles          |
| `01-1-view-definitions/` | demo 1: four ViewDefinitions                                        |
| `01-2-materialize/`      | demo 1: one AidboxMaterialization per view (Aidbox, not the spec)   |
| `02-cohort/`             | demo 2: ValueSet, data quality checks, cohort, follow-up queries    |
| `02-cohort/materialize/` | demo 2: the value set as a database view (Aidbox, not the spec)     |
| `03-omop/`               | demo 3: OMOP vocabulary subset, ConceptMaps, mapping views, reports |
| `04-ehds/`               | demo 4: opt-outs, de-identified views, an extract, an aggregate     |
| `build.py`               | packs a stage directory into one bundle (`build/<stage>.json`)      |
| `package.py`             | packs all artifacts into one FHIR package (`build/*.tgz`)           |
| `load.sh`                | loads the demo, one directory at a time                             |
| `query.sh`               | runs a view, a Library or SQL, prints CSV; `-v` shows the request   |
| `reset.sh`               | empties the server, keeps the license                               |
| `aidbox/`                | your Aidbox compose file (not in git, see [Setup](#setup))          |

Every SQLView and SQLQuery is one `.sql` file. Its header comments carry the Library metadata:

```sql
-- id: diabetes-cohort
-- title: Adults 18-75 with diabetes and a visit in 2026
-- type: sql-view
-- depends-on: patients ViewDefinition/patients
-- depends-on: vs_diabetes ValueSet/diabetes
select ...
```

`depends-on: <label> <resource>` becomes `Library.relatedArtifact`; the label is the table name the SQL uses.
A SQLQuery may also declare `param: <name> <type>`, which becomes `Library.parameter`; the SQL refers to it as `:name`.
These comments are a convention of this repository, not part of SQL on FHIR: `build.py` turns each file into a Library.

</details>

### The data

<details>
<summary>1,201 synthetic patients in three clinics, messy on purpose</summary>

1,201 synthetic patients in three clinics, 217 of them generated with diabetes, plus Maria Silva (`p-0101`, born 1968),
the patient the story follows. **The mess is deliberate**:

| Clinic   | Diagnosis codes                  | HbA1c units    |
|----------|----------------------------------|----------------|
| clinic-1 | SNOMED CT + ICD-10, or ICD-10-GM | %              |
| clinic-2 | SNOMED CT + ICD-10, or ICD-10-GM | % and mmol/mol |
| clinic-3 | a local code `DM2` only          | %              |

On top of that:

- 9 HbA1c results without a value
- 3 lab results dated before the patient's birth
- 6 lab results without a UCUM unit code
- 54 social findings recorded as Conditions ("Full-time employment", "Stress")
- 5 hypertension diagnoses with a local code that nothing maps
- 31 people with diabetes who opted out of secondary use, recorded as `Consent` resources

</details>

## Setup

1. Clone the repository. All commands below run from its root.

   ```sh
   git clone https://github.com/HealthSamurai/hl7-eu-wg-2026-analytics-on-fhir-demo.git
   cd hl7-eu-wg-2026-analytics-on-fhir-demo
   ```

2. Start Aidbox.

   ```sh
   mkdir -p aidbox && cd aidbox
   curl -JO https://aidbox.app/runme && docker compose up -d
   cd ..
   ```

3. Open <http://localhost:8080> and activate the license with your Aidbox account.
   The first start takes one to three minutes.

4. Check that the server answers. The scripts read the client secret from `aidbox/docker-compose.yaml`.

   ```sh
   ./query.sh sql "select 1 as ok"
   ```

   Expected:

   ```
   ok
   1
   ```

   `-v` also prints the request, ready to paste into the Aidbox REST console (<http://localhost:8080/u/rest>);
   `-n` prints the request without running it.

5. Load the population, the synthetic data every demo uses (see [The data](#the-data)).

   ```sh
   ./load.sh 00-population/
   ```

   Expected: `Patient: 1201`, `Organization: 3`, `Encounter: 2265`, `Condition: 277`, `Observation: 862`, `Consent: 31`.

   UI: <http://localhost:8080/u/resource/Patient>

To log in to the Aidbox UI use `admin` and the value of `BOX_ADMIN_PASSWORD` from `aidbox/docker-compose.yaml`.

## Demo 1. ViewDefinition in action

*`forEach`, `%rowIndex`, `$run` and materialization.*

Goal: turn nested FHIR resources into flat tables with ViewDefinitions.

1. Look at Maria's diagnosis as the clinic stores it. Maria Silva, born 1968, is the only Maria of that year:
   `GET /fhir/Patient?name=maria&birthdate=1968` in the REST console finds her. Then open
   <http://localhost:8080/u/resource/Condition/edit/p-0101-t2d> and find `code.coding`.

   One Condition, four codings (SNOMED CT, ICD-10, a local code, a post-coordinated SNOMED expression),
   a choice type `onsetDateTime`, a reference to the patient.

2. Load the ViewDefinitions.

   ```sh
   ./load.sh 01-1-view-definitions/
   ```

3. Run the `conditions` view.

   ```sh
   ./query.sh ViewDefinition/conditions 5
   ```

   UI: <http://localhost:8080/u/analytics/views/edit/conditions>, press **Run**.

   What to notice in the view:

   | Element                            | What it does                                      |
   |------------------------------------|---------------------------------------------------|
   | `forEach: code.coding`             | one row per coding, not per Condition             |
   | `%rowIndex`                        | keeps the order of the FHIR array as `coding_idx` |
   | `onset.ofType(dateTime)`           | unwraps the choice type `onset[x]`                |
   | `subject.getReferenceKey(Patient)` | turns the reference into a join key               |

   Try an edit without saving: replace the whole `forEach` block with columns that take the first coding,
   and run again.

   ```json
   { "column": [
       { "name": "system", "path": "code.coding.first().system" },
       { "name": "code",   "path": "code.coding.first().code" } ] }
   ```

   Hint: `code.coding.first()` picks the first coding, so system and code come from the same one.

   Now there is one row per Condition: 277 rows instead of 403, and Maria has one row instead of four.
   Her SNOMED CT code stays; the ICD-10 code, the local code and the post-coordinated expression are gone.
   Both shapes are legitimate; the view makes the choice visible.

4. Materialize the views as database views in the schema `sof` (Aidbox, see [Things to know](#things-to-know)).
   Each file in `01-2-materialize/` is an `AidboxMaterialization` resource that names the view, the schema
   and the kind of database object.

   ```sh
   ./load.sh 01-2-materialize/
   ```

   UI: <http://localhost:8080/u/database/schema/sof/conditions>

5. Query them with plain SQL.

   ```sh
   ./query.sh sql "select coding_idx, system, code from sof.conditions where patient_id = 'p-0101' order by coding_idx"
   ```

   UI: the DB console at <http://localhost:8080/u/db-console>.

   Expected:

   ```
   coding_idx,system,code
   0,http://snomed.info/sct,44054006
   1,http://hl7.org/fhir/sid/icd-10,E11.9
   2,http://clinic-1.example/codes,DIAB-T2
   3,http://snomed.info/sct,44054006:246112005=24484000
   ```

   Row counts: `sof.patients` 1,201 · `sof.conditions` 403 · `sof.visits` 2,265 · `sof.lab_results` 710.

   One more question the tables can now answer: how does each clinic code diabetes?

   ```sh
   ./query.sh sql "select p.clinic_id, c.system, count(*) as codings from sof.conditions c join sof.patients p using (patient_id) where c.code in ('44054006', 'DM2') or c.code like 'E11%' group by 1, 2 order by 1, 3 desc, 2"
   ```

   Expected:

   ```
   clinic_id,system,codings
   clinic-1,http://hl7.org/fhir/sid/icd-10,73
   clinic-1,http://snomed.info/sct,73
   clinic-1,http://fhir.de/CodeSystem/bfarm/icd-10-gm,30
   clinic-2,http://hl7.org/fhir/sid/icd-10,51
   clinic-2,http://snomed.info/sct,51
   clinic-2,http://fhir.de/CodeSystem/bfarm/icd-10-gm,18
   clinic-3,http://clinic-3.example/codes,46
   ```

   Clinic-3 uses only its own local code. Demo 2 deals with that through a ValueSet.

## Demo 2. SQLView, SQLQuery and terminology

*Quality checks, a ValueSet join, a cohort, a worklist.*

Goal: build layers on top of the flat tables. SQLViews reshape, SQLQueries answer a question,
a ValueSet is just another table to join.

1. Load the artifacts.

   ```sh
   ./load.sh 02-cohort/
   ```

2. Query the value set with SQL. The ValueSet `diabetes` is a FHIR resource, but SQL sees it as a table of codes.

   The SQL on FHIR way: `diabetes-codes` is a SQLView that names the ValueSet as a dependency
   (`-- depends-on: vs_diabetes ValueSet/diabetes`) and selects from it by its label. Any server
   that supports SQL on FHIR resolves the label to the codes.

   ```sh
   ./query.sh Library/diabetes-codes
   ```

   UI: <http://localhost:8080/u/analytics/sqlview/edit/diabetes-codes>, press **Run**.

   Plain SQL: `load.sh` also keeps that view in the database as `sof.vs_diabetes` (Aidbox, see
   [Things to know](#things-to-know)). Raw SQL cannot declare a dependency, so it reads this table instead:

   ```sh
   ./query.sh sql "select system, code from sof.vs_diabetes order by 1, 2"
   ```

   UI: the same query in the DB console at <http://localhost:8080/u/db-console>.

   Expected, nine codes from four systems (the SQLView also returns `display`):

   ```
   system,code
   http://clinic-3.example/codes,DM2
   http://fhir.de/CodeSystem/bfarm/icd-10-gm,E11.20
   ...
   ```

3. Can we trust the data? Each check is a SQLView that returns the bad rows; the summary is a SQLQuery.

   ```sh
   ./query.sh Library/dq-summary
   ./query.sh Library/dq-obs-before-birth
   ```

   UI: <http://localhost:8080/u/analytics/queries/edit/dq-summary>, press **Run**.

   Expected summary:

   | rule                | category     | bad_rows |
   |---------------------|--------------|----------|
   | hba1c-missing-value | completeness | 9        |
   | obs-before-birth    | plausibility | 3        |
   | unit-not-ucum       | conformance  | 6        |

4. Who has diabetes? Look at `02-cohort/diabetes-cohort.sql`: the same ValueSet is a dependency
   and is joined on `system` and `code`. Three clinics, three coding habits, one join.

   ```sh
   ./query.sh Library/diabetes-cohort | tail -n +2 | wc -l
   ```

   UI: <http://localhost:8080/u/analytics/sqlview/edit/diabetes-cohort>: the SQL, its dependencies, **Run**.

   Expected: `145` adults aged 18–75 with diabetes and a visit in 2026.

5. Who needs a call? `hba1c-status` takes the latest HbA1c of 2026 per person and converts mmol/mol to %.

   ```sh
   ./query.sh Library/summary
   ./query.sh Library/worklist
   ```

   UI: <http://localhost:8080/u/analytics/queries/edit/summary> and <http://localhost:8080/u/analytics/queries/edit/worklist>.

   Expected summary:

   | clinic   | diabetics | needs_follow_up | pct  |
   |----------|-----------|-----------------|------|
   | clinic-1 | 72        | 13              | 18.1 |
   | clinic-2 | 47        | 10              | 21.3 |
   | clinic-3 | 26        | 6               | 23.1 |
   | ALL      | 145       | 29              | 20.0 |

   The worklist has 29 rows. Maria (`p-0101`, HbA1c 10.2%) is one of them; 19 people are there
   because they had no test this year, not because their result is high.

6. A query with a parameter. `cohort-by-clinic` lists the cohort of one clinic. The file declares the
   parameter in its header (`-- param: clinic string`), which becomes `Library.parameter`, and the SQL
   refers to it as `:clinic`. The value is passed by name:

   ```sh
   ./query.sh Library/cohort-by-clinic clinic=clinic-3 | tail -n +2 | wc -l
   ```

   Expected: `26`. The other two clinics give 72 and 47, together the 145 of the cohort.

   Add `-v` to see the request: the value travels in a nested `Parameters` resource named `parameters`,
   as the SQL on FHIR `$sql-run` operation defines it. Only a SQLQuery may take parameters; a SQLView may not.

All views and queries of the demo are listed at <http://localhost:8080/u/analytics>.

The measure is a simplified version of CMS122 ("Glycemic Status Assessment Greater Than 9%"):
no exclusions, HbA1c by LOINC 4548-4 only.

## Demo 3. OMOP mapping in SQLViews

*"Maps to" joins, a ConceptMap, domain routing.*

Goal: produce OMOP CDM tables from the same views, and see what a naive conversion silently loses.

1. Load the vocabulary subset, the ConceptMaps and the OMOP views.

   ```sh
   ./load.sh 03-omop/
   ```

2. The OMOP vocabulary is tables. Here it is a hand-made subset of 15 concepts; a real one comes from Athena.

   ```sh
   ./query.sh sql "select concept_id, concept_name, domain_id, vocabulary_id, standard_concept, concept_code from omop.concept order by vocabulary_id, concept_code"
   ```

   UI: <http://localhost:8080/u/database/schema/omop/concept>

3. Naive mapping against explicit mapping. `condition-mapped-naive.sql` uses inner joins to the vocabulary;
   `coding-resolved.sql` and `condition-mapped.sql` translate local codes through a ConceptMap,
   use left joins, and keep unmapped records as `concept_id = 0`.

   ```sh
   ./query.sh Library/naive-vs-explicit
   ```

   UI: compare <http://localhost:8080/u/analytics/sqlview/edit/condition-mapped-naive> with
   <http://localhost:8080/u/analytics/sqlview/edit/condition-mapped>, then run
   <http://localhost:8080/u/analytics/queries/edit/naive-vs-explicit>.

   Expected, people with a diabetes diagnosis:

   | clinic   | fhir | omop_naive | omop_explicit |
   |----------|------|------------|---------------|
   | clinic-1 | 103  | 103        | 103           |
   | clinic-2 | 69   | 69         | 69            |
   | clinic-3 | 46   | 0          | 46            |
   | ALL      | 218  | 172        | 218           |

   The naive conversion drops a whole clinic and reports no error.

4. The domain decides the table. A FHIR Condition does not always become an OMOP condition.

   ```sh
   ./query.sh Library/domain-routing
   ```

   UI: <http://localhost:8080/u/analytics/queries/edit/domain-routing>

   Expected:

   | target_domain | omop_table           | concept_id | concept_name             | conditions |
   |---------------|----------------------|------------|--------------------------|------------|
   | Condition     | condition_occurrence | 201826     | Type 2 diabetes mellitus | 218        |
   | Condition     | condition_occurrence | 0          | No matching concept      | 5          |
   | Observation   | observation          | 4053118    | Full-time employment     | 40         |
   | Observation   | observation          | 4251306    | Stress                   | 14         |

   A Condition coded with both SNOMED CT and ICD-10 resolves to one concept and gives one OMOP row;
   `coding_idx` from demo 1 decides which coding supplies the source value.

5. What could not be mapped, and does it matter?

   ```sh
   ./query.sh Library/unmapped-report
   ```

   UI: <http://localhost:8080/u/analytics/queries/edit/unmapped-report>

   Expected:

   | clinic_id | source_system                 | source_code                 | codings | conditions_without_concept |
   |-----------|-------------------------------|-----------------------------|---------|----------------------------|
   | clinic-1  | http://clinic-1.example/codes | DIAB-T2                     | 1       | 0                          |
   | clinic-1  | http://snomed.info/sct        | 44054006:246112005=24484000 | 1       | 0                          |
   | clinic-2  | http://clinic-2.example/codes | HTA                         | 5       | 5                          |

   Maria's two extra codings are lost, but her Condition is still mapped through SNOMED CT.
   The five `HTA` Conditions have no concept at all and stay in `condition_occurrence` with `concept_id = 0`.

6. Look at the OMOP tables.

   ```sh
   for t in person condition-occurrence observation measurement visit-occurrence; do
     ./query.sh Library/omop-$t | head -4
   done
   ```

   UI: <http://localhost:8080/u/analytics/sqlview/edit/omop-person>; the other tables are next to it
   in the list at <http://localhost:8080/u/analytics/sqlview>.

   Row counts: person 1,201 · condition_occurrence 223 · observation 54 · measurement 710 · visit_occurrence 2,265.
   In `measurement`, HbA1c reported in mmol/mol is converted to % and the original value and unit are kept
   in `value_source_value` and `unit_source_value`.

7. The research question, asked of the OMOP tables only.

   ```sh
   ./query.sh Library/omop-follow-up
   ```

   UI: <http://localhost:8080/u/analytics/queries/edit/omop-follow-up>

   Expected: the same numbers as the summary in [demo 2](#demo-2-sqlview-sqlquery-and-terminology), step 5:
   145 people with diabetes, 29 of them need a follow-up.

## Demo 4. Secondary-use rules as views

*`Consent` opt-out, de-identified views, small-cell suppression.*

Goal: show that the rules which separate secondary use from care can be written as the same kind of artifact.
The European Health Data Space is the reason this matters in Europe, but nothing here is an official EHDS
format: it is an illustration of three ideas with FHIR resources, views and SQL.

1. Load the artifacts.

   ```sh
   ./load.sh 04-ehds/
   ```

2. Opt-out. 31 people recorded that their data must not be used for research. Each is a FHIR `Consent`
   resource; the ViewDefinition `optouts` turns them into a table.

   ```sh
   ./query.sh ViewDefinition/optouts 5
   ./query.sh Library/primary-vs-secondary
   ```

   UI: <http://localhost:8080/u/analytics/queries/edit/primary-vs-secondary>

   Expected:

   | clinic   | care_cohort | care_call_list | opted_out | research_cohort |
   |----------|-------------|----------------|-----------|-----------------|
   | clinic-1 | 72          | 13             | 13        | 59              |
   | clinic-2 | 47          | 10             | 6         | 41              |
   | clinic-3 | 26          | 6              | 3         | 23              |
   | ALL      | 145         | 29             | 22        | 123             |

   The call list still has 29 people: an opt-out from research does not remove anyone from care.
   The research cohort has 123. Of the 31 people who opted out, 22 are in the diabetes cohort.

3. De-identified views (Aidbox, see [Things to know](#things-to-know)). Three ViewDefinitions prepare data
   for research. In each, the patient id goes through the Aidbox de-identification extension with the method
   `cryptoHash`: a keyed hash, so the same person gets the same pseudonym in every view, and the id cannot be
   read back without the key.

   | ViewDefinition         | Columns                                             |
   |------------------------|-----------------------------------------------------|
   | `research_patients`    | `pseudonym`, `gender`, `birth_date`, `clinic_id`    |
   | `research_lab_results` | `pseudonym`, `effective`, `value`, `unit`, the code |
   | `research_optouts`     | `pseudonym` of everyone who opted out               |

   ```sh
   ./query.sh ViewDefinition/research_patients 3
   ```

   Expected:

   ```
   "pseudonym","gender","birth_date","clinic_id"
   "8e58c80a958df0efe21a4914c1092b249911204be69203f33f04814ffc3d2a97","female","1976-02-08","clinic-3"
   "6c69f134b01cc2782da3b605c23cb6b27cf9532b8dd4b6ef6cd07537d736f2ba","male","1984-02-24","clinic-1"
   "fe709c0531670960313ab0e8c177529a6cd4d9b0a450bf70e54dcc0cb05981f6","male","1983-02-14","clinic-2"
   ```

   UI: <http://localhost:8080/u/analytics/views/edit/research_patients>. The shield icon next to a
   column opens the de-identification settings.

4. A minimised extract. `permit-person` and `permit-hba1c` are SQLViews over the de-identified views. They
   remove the people who opted out, by pseudonym, cut the birth date to the year and the test date to the
   month, and keep only the columns a study on glycaemic control needs.

   ```sh
   ./query.sh Library/permit-person | head -4
   ./query.sh Library/permit-hba1c  | head -4
   ```

   Row counts: 1,170 people (1,201 minus 31 opt-outs), 422 HbA1c results.

   UI: <http://localhost:8080/u/analytics/sqlview/edit/permit-person>, read the SQL, press **Run**.
   What a study may see is a view someone can review and approve.

5. An aggregate answer. Some questions need no patient-level data at all. `data-request` returns counts
   by clinic and sex, and replaces any count below 5 with `<5`.

   ```sh
   ./query.sh Library/data-request
   ```

   UI: <http://localhost:8080/u/analytics/queries/edit/data-request>

   Expected:

   | clinic_id | gender | diabetics | needs_follow_up |
   |-----------|--------|-----------|-----------------|
   | clinic-1  | female | 31        | 8               |
   | clinic-1  | male   | 28        | <5              |
   | clinic-2  | female | 23        | 5               |
   | clinic-2  | male   | 18        | <5              |
   | clinic-3  | female | 12        | <5              |
   | clinic-3  | male   | 11        | <5              |

What this demo does not do: the hash key is written in the ViewDefinitions and is not a secret, the threshold
of 5 is arbitrary, and a `Consent` resource is one possible way to record an opt-out, not an agreed one.
Real key management, disclosure control and the legal process are outside its scope.

## The whole demo as one FHIR package

Everything the four demos load, apart from the data, is 39 FHIR resources: 8 ViewDefinitions, 17 SQLViews,
10 SQLQueries, 1 ValueSet and 3 ConceptMaps. `package.py` packs them into one FHIR package, the same format
implementation guides are published in.

```sh
python3 package.py
# build/org.example.analytics-on-fhir-0.1.0.tgz: 39 resources
```

To see that the package alone is enough, install it on a server that holds only the data:

```sh
./reset.sh && ./load.sh 00-population/

SECRET=$(sed -n 's/.*BOX_ROOT_CLIENT_SECRET: *//p' aidbox/docker-compose.yaml)
curl -u "root:$SECRET" -X POST 'http://localhost:8080/fhir/$upload-fhir-npm-packages' \
  -F 'package.tgz=@build/org.example.analytics-on-fhir-0.1.0.tgz;type=application/gzip'
```

Aidbox gives the resources of a package new ids, so find one by its canonical URL and run it:

```sh
ID=$(curl -s -u "root:$SECRET" \
  'http://localhost:8080/fhir/Library?url=https://example.org/aof/Library/summary&_elements=id' \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["entry"][0]["resource"]["id"])')
./query.sh Library/$ID
```

It prints the same summary as [demo 2](#demo-2-sqlview-sqlquery-and-terminology): 145 people with diabetes, 29 of
them need a follow-up. The OMOP queries also need the vocabulary tables, which are data and not part of the
package: load `03-omop/vocabulary.sql` first.

Remove the package before going back to the step-by-step demos, otherwise every artifact exists twice:

```sh
curl -u "root:$SECRET" -X POST 'http://localhost:8080/fhir/$fhir-package-uninstall' \
  -H 'content-type: application/json' \
  -d '{"resourceType":"Parameters","parameter":[{"name":"package","valueString":"org.example.analytics-on-fhir@0.1.0"}]}'
./reset.sh && ./load.sh all
```

Tested on Aidbox only. `$upload-fhir-npm-packages` and `$fhir-package-uninstall` are Aidbox operations.

## Start over

```sh
./reset.sh        # delete the demo resources and data, keep the license
./load.sh all     # load every stage again, about 10 seconds
```

To remove the server and its database completely (the license has to be activated again afterwards):

```sh
cd aidbox && docker compose down -v
```

## Things to know

- **The OMOP vocabulary here is a hand-made subset.** `03-omop/vocabulary.sql` marks every row as `[athena]`,
  `[webapi]` (checked against the public OHDSI WebAPI) or `[placeholder]`. The three placeholder ids, for the
  ICD-10-GM codes, start at 2,000,000,000 and are not OMOP concept ids. The "Maps to" rows are simplified: every
  diabetes code maps straight to 201826, while Athena maps some of them to more specific concepts.
  Use Athena (<https://athena.ohdsi.org>) for real work.
- **The OMOP tables are views, and a subset.** Each `omop-*` SQLView uses the column names of OMOP CDM v5.4:
  every required column, 47 of the 101 columns of these six tables in all. Nothing checks types or constraints,
  so this is not a validated OMOP database.
- **The OMOP ids are row numbers.** `person_id` and the other keys are `row_number()` over the source id:
  stable for this dataset, not a general solution.
- **Dependency labels must not be FHIR resource names.** In this Aidbox build a label such as `patient`
  or `encounter` shadows the resource table inside nested dependencies. The views are therefore named
  `patients`, `visits`, `conditions`, `lab_results`.
- **An empty response with HTTP 200 means a SQL error.** `$run` and `$sqlquery-run` stream the result;
  look at `docker compose logs postgres` in `aidbox/`.
- **`$run` returns 100 rows by default.** Pass `_limit`, as `query.sh ViewDefinition/<id> <limit>` does.
- **Operation names.** `$run` on ViewDefinition and `$sqlquery-run` on Library are the names in this Aidbox build.
  SQL on FHIR version 3 defines one system-level operation for both, `$sql-run`, and `$sql-export` for bulk export.
- **Materialization is Aidbox, not SQL on FHIR.** The spec leaves it to the server whether a view is stored or
  computed on the fly. Demo 1, step 4 uses the `AidboxMaterialization` resource, which keeps materialization
  manageable through the API; Aidbox also has a plain `$materialize` call. This build cannot materialize a
  ValueSet directly, only a ViewDefinition or a SQLView, so `sof.vs_diabetes` in demo 2 goes through a SQLView.
  Nothing else depends on materialization: the Libraries read the ViewDefinitions, not the `sof` views.
- **Demo 4 illustrates ideas, not EHDS requirements.** The opt-out as a `Consent`, the pseudonym and the
  small-cell threshold are modelling choices made for this demo.
- **De-identification is Aidbox, not SQL on FHIR.** The `research_*` ViewDefinitions use an Aidbox extension
  on their pseudonym column (Aidbox 2604 or newer). The specification has no de-identification yet; issue
  [#334](https://github.com/HL7/sql-on-fhir/issues/334) proposes it, and another runner may ignore the extension
  and return the raw values. The keys are stored in the ViewDefinition in plain text, and such a view cannot be
  materialized through `AidboxMaterialization`. The EHDS Regulation (EU) 2025/327 gives the right to opt out of
  secondary use (Article 71) and asks for anonymised or pseudonymised data (Article 66); it sets no minimum cell size.
- **The data is synthetic.** The ICD-10-GM codes are illustrative. The post-coordinated SNOMED CT expression on
  Maria's Condition is valid: it was checked with `$validate-code` on tx.fhir.org.

## Links

- [Slides of the session](https://www.health-samurai.io/presentations/hl7-eu-wg-2026-analytics-on-fhir)
- [SQL on FHIR](https://sql-on-fhir.org) · [implementation guide](https://build.fhir.org/ig/HL7/sql-on-fhir/en/) · [repository](https://github.com/HL7/sql-on-fhir)
- [fhir2omop](https://github.com/lampadephoros/fhir2omop): FHIR to OMOP with SQL on FHIR, the project this demo borrows its approach from
- [OMOP Common Data Model](https://ohdsi.github.io/CommonDataModel/)
- [Aidbox](https://www.health-samurai.io/fhir-server)
- [Interoperable analytics with SQL on FHIR](https://www.health-samurai.io/articles/sql-on-fhir-interoperable-analytics)
- [Analytics on FHIR 2026](https://www.health-samurai.io/events/analytics-on-fhir-2026): free online conference, 3 and 8 December 2026
- [#analytics on FHIR](https://chat.fhir.org/#narrow/stream/analytics.20on.20FHIR) on chat.fhir.org

## License

BSD 3-Clause, see [LICENSE](LICENSE). The population generator is based on the demo of Nikolai Ryzhikov
for FHIR North 2026.
