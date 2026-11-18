-- id: cohort-by-clinic
-- title: The diabetes cohort of one clinic
-- type: sql-query
-- param: clinic string
-- depends-on: cohort Library/diabetes-cohort
select patient_id, birth_date
from cohort
where clinic_id = :clinic
order by patient_id
