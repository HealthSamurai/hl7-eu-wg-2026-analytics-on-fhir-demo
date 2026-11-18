-- id: data-request
-- title: An aggregate answer only: counts by clinic and sex, small cells suppressed
-- type: sql-query
-- depends-on: status Library/hba1c-status
-- depends-on: patients ViewDefinition/patients
-- depends-on: optouts ViewDefinition/optouts
with counted as (
  select s.clinic_id, p.gender,
         count(*)                                as diabetics,
         count(*) filter (where needs_follow_up) as needs_follow_up
  from status s
  join patients p on p.patient_id = s.patient_id
  where not exists (select 1 from optouts o where o.patient_id = s.patient_id)
  group by s.clinic_id, p.gender)
select clinic_id, gender,
       case when diabetics       < 5 then '<5' else diabetics::text       end as diabetics,
       case when needs_follow_up < 5 then '<5' else needs_follow_up::text end as needs_follow_up
from counted
order by clinic_id, gender
