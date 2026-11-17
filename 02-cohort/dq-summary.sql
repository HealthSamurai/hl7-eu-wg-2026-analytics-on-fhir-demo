-- id: dq-summary
-- title: Data quality summary: one row per check
-- type: sql-query
-- depends-on: missing Library/dq-hba1c-missing-value
-- depends-on: before_birth Library/dq-obs-before-birth
-- depends-on: not_ucum Library/dq-unit-not-ucum
select 'hba1c-missing-value' as rule, 'completeness' as category, count(*) as bad_rows from missing
union all
select 'obs-before-birth', 'plausibility', count(*) from before_birth
union all
select 'unit-not-ucum', 'conformance', count(*) from not_ucum
