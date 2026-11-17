-- id: dq-unit-not-ucum
-- title: Data quality: value without a UCUM unit code (conformance)
-- type: sql-view
-- depends-on: lab_results ViewDefinition/lab_results
select obs_id, patient_id, code, value
from lab_results
where value is not null and unit is null
order by obs_id
