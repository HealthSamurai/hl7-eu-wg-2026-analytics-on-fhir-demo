-- id: primary-vs-secondary
-- title: The same people under two rules: everyone for care, minus opt-outs for research
-- type: sql-query
-- depends-on: status Library/hba1c-status
-- depends-on: optouts ViewDefinition/optouts
select coalesce(s.clinic_id, 'ALL') as clinic,
       count(*)                                              as care_cohort,
       count(*) filter (where needs_follow_up)               as care_call_list,
       count(*) filter (where o.patient_id is not null)      as opted_out,
       count(*) filter (where o.patient_id is null)          as research_cohort
from status s
left join optouts o on o.patient_id = s.patient_id
group by rollup(s.clinic_id)
order by s.clinic_id nulls last
