-- id: worklist
-- title: Call list: who needs follow-up and why
-- type: sql-query
-- depends-on: status Library/hba1c-status
select patient_id, clinic_id, hba1c_pct, last_test,
       case when hba1c_pct is null then 'no HbA1c this year' else 'HbA1c > 9%' end as reason
from status
where needs_follow_up
order by hba1c_pct desc nulls first, patient_id
