-- id: diabetes-cohort
-- title: Adults 18-75 with diabetes and a visit in 2026
-- type: sql-view
-- depends-on: patients ViewDefinition/patients
-- depends-on: conditions ViewDefinition/conditions
-- depends-on: visits ViewDefinition/visits
-- depends-on: vs_diabetes ValueSet/diabetes
select p.patient_id, p.clinic_id, p.birth_date
from patients p
where date_part('year', age(date '2026-12-31', p.birth_date::date)) between 18 and 75
  and exists (select 1 from conditions c
              join vs_diabetes vs on vs.system = c.system and vs.code = c.code
              where c.patient_id = p.patient_id)
  and exists (select 1 from visits e
              where e.patient_id = p.patient_id
                and e.start::date between date '2026-01-01' and date '2026-12-31')
