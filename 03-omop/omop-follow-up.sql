-- id: omop-follow-up
-- title: The research question on OMOP tables only: adults with diabetes, latest HbA1c in 2026 above 9% or missing
-- type: sql-query
-- depends-on: person Library/omop-person
-- depends-on: care_site Library/omop-care-site
-- depends-on: condition_occurrence Library/omop-condition-occurrence
-- depends-on: visit_occurrence Library/omop-visit-occurrence
-- depends-on: measurement Library/omop-measurement
with cohort as (
  select p.person_id, p.care_site_id
  from person p
  where date_part('year', age(date '2026-12-31', p.birth_datetime::date)) between 18 and 75
    and exists (select 1 from condition_occurrence c
                where c.person_id = p.person_id and c.condition_concept_id in (201826, 201820))
    and exists (select 1 from visit_occurrence v
                where v.person_id = p.person_id
                  and v.visit_start_date between date '2026-01-01' and date '2026-12-31')),
last_a1c as (
  select distinct on (person_id) person_id, value_as_number
  from measurement
  where measurement_concept_id = 3004410 and value_as_number is not null
    and measurement_date between date '2026-01-01' and date '2026-12-31'
  order by person_id, measurement_datetime desc)
select coalesce(cs.care_site_source_value, 'ALL') as clinic, count(*) as diabetics,
       count(*) filter (where a.value_as_number is null or a.value_as_number > 9) as needs_follow_up
from cohort c
join care_site cs on cs.care_site_id = c.care_site_id
left join last_a1c a on a.person_id = c.person_id
group by rollup(cs.care_site_source_value)
order by cs.care_site_source_value nulls last
