-- id: omop-person
-- title: OMOP person
-- type: sql-view
-- depends-on: patients ViewDefinition/patients
-- depends-on: care_site Library/omop-care-site
-- depends-on: gender_map ConceptMap/gender-to-omop
select row_number() over (order by p.patient_id)::int      as person_id,
       coalesce(g.target_code::int, 0)                     as gender_concept_id,
       extract(year  from p.birth_date::date)::int         as year_of_birth,
       extract(month from p.birth_date::date)::int         as month_of_birth,
       extract(day   from p.birth_date::date)::int         as day_of_birth,
       p.birth_date::timestamp                             as birth_datetime,
       0                                                   as race_concept_id,
       0                                                   as ethnicity_concept_id,
       cs.care_site_id,
       p.patient_id                                        as person_source_value,
       p.gender                                            as gender_source_value
from patients p
left join gender_map g on g.source_code = p.gender
left join care_site cs on cs.care_site_source_value = p.clinic_id
