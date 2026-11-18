-- A hand-made subset of the OMOP standardized vocabularies: just enough rows for this demo.
-- In a real project these tables are loaded from Athena (https://athena.ohdsi.org), about 6 million concepts.
--
-- Provenance of the rows:
--   [athena]      taken from the vocabulary seed of github.com/lampadephoros/fhir2omop, which is generated from Athena
--   [webapi]      concept_id, name and domain checked on 18 Nov 2026 against the public OHDSI WebAPI
--                 (atlas-demo.ohdsi.org/WebAPI/vocabulary)
--   [placeholder] concept_id is NOT a real OMOP id (ids >= 2,000,000,000 are reserved for local use): the
--                 ICD10GM vocabulary is not on the public server; look the codes up in Athena before using
--                 this file for anything but the demo
-- The "Maps to" rows of the source concepts are simplified: all of them point to 201826 "Type 2 diabetes
-- mellitus". In Athena, ICD10 E11.9 maps to 4193704 "Type 2 diabetes mellitus without complication", a
-- descendant of 201826, and a real cohort is defined as 201826 and its descendants (table concept_ancestor).

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
  (4053118,    'Full-time employment',                     'Observation',  'SNOMED',       'S',  '160903007'),   -- [webapi]
  (4251306,    'Stress',                                   'Observation',  'SNOMED',       'S',  '73595000'),    -- [webapi]
  (3004410,    'Hemoglobin A1c/Hemoglobin.total in Blood', 'Measurement',  'LOINC',        'S',  '4548-4'),      -- [webapi]
  (8554,       'percent',                                  'Unit',         'UCUM',         'S',  '%'),           -- [webapi]
  (8507,       'MALE',                                     'Gender',       'Gender',       'S',  'M'),           -- [athena]
  (8532,       'FEMALE',                                   'Gender',       'Gender',       'S',  'F'),           -- [athena]
  (9202,       'Outpatient Visit',                         'Visit',        'Visit',        'S',  'OP'),          -- [athena]
  (32817,      'EHR',                                      'Type Concept', 'Type Concept', 'S',  'OMOP4976890'), -- [athena]
  (32856,      'Lab',                                      'Type Concept', 'Type Concept', 'S',  'OMOP4976929'), -- [athena]
  -- source concepts: valid codes, but not the standard representation
  (45561952,   'Type 2 diabetes mellitus, without complications',                 'Condition', 'ICD10',   null, 'E11.9'),  -- [webapi]
  (2000000021, 'Type 2 diabetes mellitus without complications, controlled',      'Condition', 'ICD10GM', null, 'E11.90'), -- [placeholder]
  (2000000022, 'Type 2 diabetes mellitus without complications, uncontrolled',    'Condition', 'ICD10GM', null, 'E11.91'), -- [placeholder]
  (2000000023, 'Type 2 diabetes mellitus with renal complications, controlled',   'Condition', 'ICD10GM', null, 'E11.20'); -- [placeholder]

insert into omop.concept_relationship values
  -- a standard concept maps to itself
  (201826, 201826, 'Maps to'), (201820, 201820, 'Maps to'),
  (4053118, 4053118, 'Maps to'), (4251306, 4251306, 'Maps to'),
  (3004410, 3004410, 'Maps to'), (8554, 8554, 'Maps to'),
  -- source concepts map to a standard concept
  (45561952, 201826, 'Maps to'),  -- simplified, see the header
  (2000000021, 201826, 'Maps to'), (2000000022, 201826, 'Maps to'), (2000000023, 201826, 'Maps to');
