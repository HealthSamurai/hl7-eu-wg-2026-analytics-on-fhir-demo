-- id: permit-hba1c
-- title: Research extract, HbA1c results of the people in the extract, month of the test only
-- type: sql-view
-- depends-on: labs ViewDefinition/research_lab_results
-- depends-on: optouts ViewDefinition/research_optouts
select l.pseudonym,
       left(l.effective::text, 7) as measurement_month,   -- the month only
       case l.unit when 'mmol/mol' then round(l.value::numeric * 0.0915 + 2.15, 1)
                   else l.value::numeric end as hba1c_pct
from labs l
where l.code = '4548-4'
  and l.value is not null
  and not exists (select 1 from optouts o where o.pseudonym = l.pseudonym)
