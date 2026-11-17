-- id: omop-care-site
-- title: OMOP care_site
-- type: sql-view
-- depends-on: patients ViewDefinition/patients
select row_number() over (order by clinic_id)::int as care_site_id,
       clinic_id                                   as care_site_source_value
from (select distinct clinic_id from patients where clinic_id is not null) c
