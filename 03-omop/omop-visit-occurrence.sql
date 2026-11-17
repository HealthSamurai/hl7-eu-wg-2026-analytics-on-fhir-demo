-- id: omop-visit-occurrence
-- title: OMOP visit_occurrence
-- type: sql-view
-- depends-on: visits ViewDefinition/visits
-- depends-on: person Library/omop-person
-- depends-on: care_site Library/omop-care-site
select row_number() over (order by e.encounter_id)::int as visit_occurrence_id,
       p.person_id,
       case e.class when 'AMB' then 9202 else 0 end     as visit_concept_id,
       e.start::date                                    as visit_start_date,
       e."end"::date                                    as visit_end_date,
       32817                                            as visit_type_concept_id,
       cs.care_site_id,
       e.encounter_id                                   as visit_source_value
from visits e
join person p          on p.person_source_value = e.patient_id
left join care_site cs on cs.care_site_source_value = e.clinic_id
