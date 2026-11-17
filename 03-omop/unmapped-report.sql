-- id: unmapped-report
-- title: Codings with no OMOP concept, and whether the whole Condition lost its meaning
-- type: sql-query
-- depends-on: resolved Library/coding-resolved
-- depends-on: mapped Library/condition-mapped
-- depends-on: patients ViewDefinition/patients
select p.clinic_id, r.source_system, r.source_code,
       count(*) as codings,
       count(*) filter (where m.concept_id = 0) as conditions_without_concept
from resolved r
join patients p on p.patient_id = r.patient_id
left join mapped m on m.condition_id = r.condition_id and m.concept_id = 0
where r.concept_id is null
group by p.clinic_id, r.source_system, r.source_code
order by p.clinic_id, codings desc
