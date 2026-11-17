-- id: condition-mapped
-- title: Explicit mapping: one row per Condition and standard concept; nothing is dropped
-- type: sql-view
-- depends-on: resolved Library/coding-resolved
with mapped as (
  -- SNOMED + ICD-10 on one Condition resolve to the same concept: keep one row, from the first coding
  select distinct on (condition_id, concept_id) *
  from resolved
  where concept_id is not null
  order by condition_id, concept_id, coding_idx),
unmapped as (
  -- a Condition with no mapped coding at all stays, as concept_id = 0, with its source code
  select distinct on (condition_id)
         condition_id, patient_id, onset, coding_idx, source_system, source_code,
         0 as source_concept_id, 0 as concept_id, 'No matching concept' as concept_name, 'Condition' as target_domain
  from resolved
  where condition_id not in (select condition_id from mapped)
  order by condition_id, coding_idx)
select * from mapped
union all
select * from unmapped
