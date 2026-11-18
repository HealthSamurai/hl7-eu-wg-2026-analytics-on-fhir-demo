-- id: permit-hba1c
-- title: Research extract, HbA1c results of the people in the extract
-- type: sql-view
-- depends-on: person Library/omop-person
-- depends-on: measurement Library/omop-measurement
-- depends-on: optouts ViewDefinition/optouts
select md5('demo-salt:' || p.person_source_value) as person_pseudonym,
       date_trunc('month', m.measurement_date)::date as measurement_month,  -- month, not the exact day
       m.value_as_number                             as hba1c_pct
from measurement m
join person p on p.person_id = m.person_id
where m.measurement_concept_id = 3004410
  and m.value_as_number is not null
  and not exists (select 1 from optouts o where o.patient_id = p.person_source_value)
