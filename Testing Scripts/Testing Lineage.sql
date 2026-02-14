
declare @defaultschema varchar(max) = 'dbo'

SELECT  
    referenced_server_name = Coalesce(referenced_server_name, @@SERVERNAME)
    , referenced_database_name = Coalesce(referenced_database_name, DB_NAME())
    , referenced_schema_name = Coalesce(referenced_schema_name, @defaultschema)
    , referenced_entity_name AS object_name
    , referenced_class_desc AS object_type
    , referenced_id
    , is_selected
    , is_updated
FROM
    sys.dm_sql_referenced_entities ('dbo.usp_ComplexQueryParserTest', 'OBJECT')
Where
    referenced_minor_name is null


/*

is_updated = 1 on sys.dm_sql_referenced_entities
Inserts
Deletes
Updates

*/

/*

Object Definitions
CREATE
ALTER
DROP
TRUNCATE

*/


/* Unfound 

SELECT
FROM
WHERE
GROUP BY
HAVING
ORDER
DISTINCT
HAVING
TOP
JOIN

*/

