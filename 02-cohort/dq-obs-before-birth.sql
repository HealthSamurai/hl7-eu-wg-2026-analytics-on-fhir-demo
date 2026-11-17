-- id: dq-obs-before-birth
-- title: Data quality: lab result dated before birth (plausibility)
-- type: sql-view
-- depends-on: lab_results ViewDefinition/lab_results
-- depends-on: patients ViewDefinition/patients
select o.obs_id, o.patient_id, o.code, o.effective, p.birth_date
from lab_results o
join patients p on p.patient_id = o.patient_id
where o.effective::date < p.birth_date::date
order by o.obs_id
