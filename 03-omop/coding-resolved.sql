-- id: coding-resolved
-- title: Every Condition coding with its OMOP standard concept, or null when there is none
-- type: sql-view
-- depends-on: conditions ViewDefinition/conditions
-- depends-on: system_map ConceptMap/fhir-system-to-omop-vocabulary
-- depends-on: local_map ConceptMap/clinic3-local-to-snomed
with translated as (
  -- local codes are first translated to a standard code system through a ConceptMap
  select c.*,
         coalesce(lm.target_system, c.system) as map_system,
         coalesce(lm.target_code,   c.code)   as map_code
  from conditions c
  left join local_map lm on lm.source_system = c.system and lm.source_code = c.code)
select t.condition_id, t.patient_id, t.onset, t.coding_idx,
       t.system         as source_system,
       t.code           as source_code,
       case when t.map_code = t.code then src.concept_id else 0 end as source_concept_id,  -- a local code has no OMOP source concept
       std.concept_id   as concept_id,
       std.concept_name as concept_name,
       std.domain_id    as target_domain
from translated t
left join system_map sm              on sm.source_code = t.map_system
left join omop.concept src           on src.vocabulary_id = sm.target_code and src.concept_code = t.map_code
left join omop.concept_relationship r on r.concept_id_1 = src.concept_id and r.relationship_id = 'Maps to'
left join omop.concept std           on std.concept_id = r.concept_id_2 and std.standard_concept = 'S'
