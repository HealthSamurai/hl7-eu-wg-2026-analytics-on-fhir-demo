-- id: omop-measurement
-- title: OMOP measurement: lab results, HbA1c normalised to percent
-- type: sql-view
-- depends-on: lab_results ViewDefinition/lab_results
-- depends-on: person Library/omop-person
-- depends-on: system_map ConceptMap/fhir-system-to-omop-vocabulary
select row_number() over (order by o.obs_id)::int as measurement_id,
       p.person_id,
       coalesce(std.concept_id, 0)                as measurement_concept_id,
       o.effective::date                          as measurement_date,
       o.effective::timestamptz                   as measurement_datetime,
       32856                                      as measurement_type_concept_id,
       case when o.code = '4548-4' and o.unit = 'mmol/mol'
            then round(o.value::numeric * 0.0915 + 2.15, 1)   -- IFCC mmol/mol to NGSP %
            else o.value::numeric end             as value_as_number,
       case when o.code = '4548-4' and o.unit in ('%', 'mmol/mol') then 8554
            else coalesce(u.concept_id, 0) end    as unit_concept_id,
       o.code                                     as measurement_source_value,
       coalesce(src.concept_id, 0)                as measurement_source_concept_id,
       o.unit                                     as unit_source_value,
       o.value::text                              as value_source_value
from lab_results o
join person p                        on p.person_source_value = o.patient_id
left join system_map sm              on sm.source_code = o.system
left join omop.concept src           on src.vocabulary_id = sm.target_code and src.concept_code = o.code
left join omop.concept_relationship r on r.concept_id_1 = src.concept_id and r.relationship_id = 'Maps to'
left join omop.concept std           on std.concept_id = r.concept_id_2 and std.standard_concept = 'S'
left join omop.concept u             on u.vocabulary_id = 'UCUM' and u.concept_code = o.unit
