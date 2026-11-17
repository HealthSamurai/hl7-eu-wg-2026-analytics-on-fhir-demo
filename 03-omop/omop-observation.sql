-- id: omop-observation
-- title: OMOP observation: mapped Conditions whose standard concept is in the Observation domain
-- type: sql-view
-- depends-on: mapped Library/condition-mapped
-- depends-on: person Library/omop-person
select row_number() over (order by m.condition_id, m.concept_id)::int as observation_id,
       p.person_id,
       m.concept_id        as observation_concept_id,
       m.onset::date       as observation_date,
       32817               as observation_type_concept_id,
       m.source_code       as observation_source_value,
       m.source_concept_id as observation_source_concept_id
from mapped m
join person p on p.person_source_value = m.patient_id
where m.target_domain = 'Observation'
