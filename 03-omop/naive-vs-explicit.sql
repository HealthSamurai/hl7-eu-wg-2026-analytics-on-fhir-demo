-- id: naive-vs-explicit
-- title: People with diabetes per clinic: FHIR data, naive OMOP mapping, explicit OMOP mapping
-- type: sql-query
-- depends-on: patients ViewDefinition/patients
-- depends-on: conditions ViewDefinition/conditions
-- depends-on: vs_diabetes ValueSet/diabetes
-- depends-on: naive Library/condition-mapped-naive
-- depends-on: explicit Library/condition-mapped
select coalesce(p.clinic_id, 'ALL') as clinic,
       count(*) filter (where exists (select 1 from conditions c
                                      join vs_diabetes vs on vs.system = c.system and vs.code = c.code
                                      where c.patient_id = p.patient_id)) as fhir,
       count(*) filter (where exists (select 1 from naive n
                                      where n.patient_id = p.patient_id and n.concept_id in (201826, 201820))) as omop_naive,
       count(*) filter (where exists (select 1 from explicit e
                                      where e.patient_id = p.patient_id and e.concept_id in (201826, 201820))) as omop_explicit
from patients p
group by rollup(p.clinic_id)
order by p.clinic_id nulls last
