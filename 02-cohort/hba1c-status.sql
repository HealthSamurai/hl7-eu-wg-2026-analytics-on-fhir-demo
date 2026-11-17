-- id: hba1c-status
-- title: Latest HbA1c in 2026 per cohort member, units normalised to %
-- type: sql-view
-- depends-on: cohort Library/diabetes-cohort
-- depends-on: lab_results ViewDefinition/lab_results
with hba1c as (
  select patient_id, effective::timestamptz as effective,
         case unit when 'mmol/mol' then round(value::numeric * 0.0915 + 2.15, 1)
                   else value::numeric end as hba1c_pct
  from lab_results
  where code = '4548-4' and value is not null
    and effective::date between date '2026-01-01' and date '2026-12-31'),
last_a1c as (
  select *, row_number() over (partition by patient_id order by effective desc) as rn
  from hba1c)
select c.clinic_id, c.patient_id, a.hba1c_pct, a.effective::date as last_test,
       (a.hba1c_pct is null or a.hba1c_pct > 9) as needs_follow_up
from cohort c
left join last_a1c a on a.patient_id = c.patient_id and a.rn = 1
