-- id: domain-routing
-- title: Where FHIR Conditions land in OMOP
-- type: sql-query
-- depends-on: mapped Library/condition-mapped
select target_domain,
       case target_domain when 'Condition' then 'condition_occurrence'
                          when 'Observation' then 'observation'
                          when 'Measurement' then 'measurement'
                          when 'Procedure' then 'procedure_occurrence' end as omop_table,
       concept_id, concept_name, count(*) as conditions
from mapped
group by target_domain, concept_id, concept_name
order by target_domain, conditions desc
