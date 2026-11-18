-- id: permit-person
-- title: Research extract, people: no opt-outs, no identifiers, only the columns the study needs
-- type: sql-view
-- depends-on: person Library/omop-person
-- depends-on: optouts ViewDefinition/optouts
select md5('demo-salt:' || p.person_source_value) as person_pseudonym,   -- a real salt is a secret, not a literal
       p.gender_concept_id,
       p.year_of_birth,                                                  -- year only: month and day stay behind
       p.care_site_id
from person p
where not exists (select 1 from optouts o where o.patient_id = p.person_source_value)
