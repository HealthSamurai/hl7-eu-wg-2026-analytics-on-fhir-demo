-- id: omop-condition-occurrence
-- title: OMOP condition_occurrence: mapped Conditions whose standard concept is in the Condition domain
-- type: sql-view
-- depends-on: mapped Library/condition-mapped
-- depends-on: person Library/omop-person
select row_number() over (order by m.condition_id, m.concept_id)::int as condition_occurrence_id,
       p.person_id,
       m.concept_id        as condition_concept_id,
       m.onset::date       as condition_start_date,
       32817               as condition_type_concept_id,
       m.source_code       as condition_source_value,
       m.source_concept_id as condition_source_concept_id
from mapped m
join person p on p.person_source_value = m.patient_id
where m.target_domain = 'Condition'
