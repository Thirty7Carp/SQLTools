SELECT DISTINCT
    'ParsedOnly' AS ComparisonResult,
    p.SourceServer,
    p.SourceDatabase,
    p.SourceSchema,
    p.SourceObject,
    p.OperationType,
    p.TargetServer,
    p.TargetDatabase,
    p.TargetSchema,
    p.TargetObject
FROM
    Utility.LineageObjectParsedDependency p
    INNER JOIN Utility.LineageObjectList ol
        ON ol.ServerName = p.TargetServer
        AND ol.DatabaseName = p.TargetDatabase
        AND ol.SchemaName = p.TargetSchema
        AND ol.ObjectName = p.TargetObject
WHERE NOT EXISTS (
    SELECT 1
    FROM Utility.LineageObjectExpressionDependency e
    WHERE
        e.ReferencingServer = p.SourceServer
        AND e.ReferencingDatabase = p.SourceDatabase
        AND e.ReferencingSchema = p.SourceSchema
        AND e.ReferencingObject = p.SourceObject
        AND e.referenced_server_name = p.TargetServer
        AND e.referenced_database_name = p.TargetDatabase
        AND e.referenced_schema_name = p.TargetSchema
        AND e.referenced_entity_name = p.TargetObject
)

UNION ALL

SELECT DISTINCT
    'ExpressionOnly' AS ComparisonResult,
    e.ReferencingServer,
    e.ReferencingDatabase,
    e.ReferencingSchema,
    e.ReferencingObject,
    NULL AS OperationType,
    e.referenced_server_name,
    e.referenced_database_name,
    e.referenced_schema_name,
    e.referenced_entity_name
FROM
    Utility.LineageObjectExpressionDependency e
    INNER JOIN Utility.LineageObjectList ol
        ON ol.ServerName = e.referenced_server_name
        AND ol.DatabaseName = e.referenced_database_name
        AND ol.SchemaName = e.referenced_schema_name
        AND ol.ObjectName = e.referenced_entity_name
WHERE NOT EXISTS (
    SELECT 1
    FROM Utility.LineageObjectParsedDependency p
    WHERE
        p.SourceServer = e.ReferencingServer
        AND p.SourceDatabase = e.ReferencingDatabase
        AND p.SourceSchema = e.ReferencingSchema
        AND p.SourceObject = e.ReferencingObject
        AND p.TargetServer = e.referenced_server_name
        AND p.TargetDatabase = e.referenced_database_name
        AND p.TargetSchema = e.referenced_schema_name
        AND p.TargetObject = e.referenced_entity_name
)

ORDER BY
    ComparisonResult,
    SourceServer,
    SourceDatabase,
    SourceSchema,
    SourceObject;


