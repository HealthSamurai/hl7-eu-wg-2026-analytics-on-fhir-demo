-- id: diabetes-codes
-- title: The diabetes value set, as SQL sees it
-- type: sql-query
-- depends-on: vs_diabetes ValueSet/diabetes
select system, code, display from vs_diabetes order by system, code
