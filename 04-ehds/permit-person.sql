-- id: permit-person
-- title: Research extract, people: the de-identified view, minus the opt-outs, year of birth only
-- type: sql-view
-- depends-on: people ViewDefinition/research_patients
-- depends-on: optouts ViewDefinition/research_optouts
select p.pseudonym, p.gender,
       left(p.birth_date::text, 4) as birth_year,   -- the year only
       p.clinic_id
from people p
where not exists (select 1 from optouts o where o.pseudonym = p.pseudonym)
