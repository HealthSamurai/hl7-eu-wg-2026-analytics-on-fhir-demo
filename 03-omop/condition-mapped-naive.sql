-- id: condition-mapped-naive
-- title: Naive mapping: inner joins to the vocabulary, whatever does not match is dropped
-- type: sql-view
-- depends-on: conditions ViewDefinition/conditions
-- depends-on: system_map ConceptMap/fhir-system-to-omop-vocabulary
select c.condition_id, c.patient_id, c.onset,
       std.concept_id   as concept_id,
       std.concept_name as concept_name,
       std.domain_id    as target_domain,
       c.system         as source_system,
       c.code           as source_code,
       src.concept_id   as source_concept_id
from conditions c
join system_map sm              on sm.source_code = c.system
join omop.concept src           on src.vocabulary_id = sm.target_code and src.concept_code = c.code
join omop.concept_relationship r on r.concept_id_1 = src.concept_id and r.relationship_id = 'Maps to'
join omop.concept std           on std.concept_id = r.concept_id_2 and std.standard_concept = 'S'
