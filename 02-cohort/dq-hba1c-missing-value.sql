-- id: dq-hba1c-missing-value
-- title: Data quality: HbA1c without a value (completeness)
-- type: sql-view
-- depends-on: lab_results ViewDefinition/lab_results
select obs_id, patient_id, effective
from lab_results
where code = '4548-4' and value is null
order by obs_id
