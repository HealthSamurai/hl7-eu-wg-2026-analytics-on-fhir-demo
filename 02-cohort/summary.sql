-- id: summary
-- title: Diabetes follow-up by clinic: HbA1c > 9% or no test in 2026
-- type: sql-query
-- depends-on: status Library/hba1c-status
select coalesce(clinic_id, 'ALL') as clinic, count(*) as diabetics,
       count(*) filter (where needs_follow_up) as needs_follow_up,
       round(100.0 * count(*) filter (where needs_follow_up) / count(*), 1) as pct
from status
group by rollup(clinic_id)
order by clinic_id nulls last
