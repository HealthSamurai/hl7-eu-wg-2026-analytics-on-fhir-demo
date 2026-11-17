-- A hand-made subset of the OMOP standardized vocabularies: just enough rows for this demo.
-- In a real project these tables are loaded from Athena (https://athena.ohdsi.org), about 6 million concepts.
--
-- Provenance of the rows:
--   [athena]      taken from the vocabulary seed of github.com/lampadephoros/fhir2omop, which is generated from Athena
--   [unverified]  concept_id written from memory, not checked against Athena
--   [placeholder] concept_id is NOT a real OMOP id (ids >= 2,000,000,000 are reserved for local use);
--                 look the code up in Athena before using this file for anything but the demo
-- The ICD10GM rows are simplified: all three map to "Type 2 diabetes mellitus"; Athena maps codes with
-- complications to more specific concepts.

create schema if not exists omop;
drop table if exists omop.concept, omop.concept_relationship;

create table omop.concept (
  concept_id       integer primary key,
  concept_name     text not null,
  domain_id        text not null,
  vocabulary_id    text not null,
  standard_concept text,           -- 'S' = standard concept, null = source concept
  concept_code     text not null
);

create table omop.concept_relationship (
  concept_id_1    integer not null,
  concept_id_2    integer not null,
  relationship_id text not null
);

insert into omop.concept values
  -- standard concepts
  (201826,     'Type 2 diabetes mellitus',                 'Condition',    'SNOMED',       'S',  '44054006'),    -- [athena]
  (201820,     'Diabetes mellitus',                        'Condition',    'SNOMED',       'S',  '73211009'),    -- [athena]
  (2000000001, 'Full-time employment',                     'Observation',  'SNOMED',       'S',  '160903007'),   -- [placeholder] domain per fhir2omop
  (2000000002, 'Stress',                                   'Observation',  'SNOMED',       'S',  '73595000'),    -- [placeholder] domain per fhir2omop
  (3004410,    'Hemoglobin A1c/Hemoglobin.total in Blood', 'Measurement',  'LOINC',        'S',  '4548-4'),      -- [unverified]
  (8554,       'percent',                                  'Unit',         'UCUM',         'S',  '%'),           -- [unverified]
  (8507,       'MALE',                                     'Gender',       'Gender',       'S',  'M'),           -- [athena]
  (8532,       'FEMALE',                                   'Gender',       'Gender',       'S',  'F'),           -- [athena]
  (9202,       'Outpatient Visit',                         'Visit',        'Visit',        'S',  'OP'),          -- [athena]
  (32817,      'EHR',                                      'Type Concept', 'Type Concept', 'S',  'OMOP4976890'), -- [athena]
  (32856,      'Lab',                                      'Type Concept', 'Type Concept', 'S',  'OMOP4976929'), -- [athena]
  -- source concepts: valid codes, but not the standard representation
  (2000000011, 'Type 2 diabetes mellitus without complications',                  'Condition', 'ICD10',   null, 'E11.9'),  -- [placeholder]
  (2000000021, 'Type 2 diabetes mellitus without complications, controlled',      'Condition', 'ICD10GM', null, 'E11.90'), -- [placeholder]
  (2000000022, 'Type 2 diabetes mellitus without complications, uncontrolled',    'Condition', 'ICD10GM', null, 'E11.91'), -- [placeholder]
  (2000000023, 'Type 2 diabetes mellitus with renal complications, controlled',   'Condition', 'ICD10GM', null, 'E11.20'); -- [placeholder]

insert into omop.concept_relationship values
  -- a standard concept maps to itself
  (201826, 201826, 'Maps to'), (201820, 201820, 'Maps to'),
  (2000000001, 2000000001, 'Maps to'), (2000000002, 2000000002, 'Maps to'),
  (3004410, 3004410, 'Maps to'), (8554, 8554, 'Maps to'),
  -- source concepts map to a standard concept
  (2000000011, 201826, 'Maps to'),
  (2000000021, 201826, 'Maps to'), (2000000022, 201826, 'Maps to'), (2000000023, 201826, 'Maps to');
