drop table if exists #ObjectParsedDependencySwitch 

    Select
        SourceServer =      case when operationtype in ('EXECUTE', 'SELECT') then pd.TargetServer else pd.SourceServer end ,
        SourceDatabase =    case when operationtype in ('EXECUTE', 'SELECT') then pd.TargetDatabase else pd.SourceDatabase end ,
        SourceSchema =      case when operationtype in ('EXECUTE', 'SELECT') then pd.TargetSchema else pd.SourceSchema end ,
        SourceObject =      case when operationtype in ('EXECUTE', 'SELECT') then pd.TargetObject else pd.SourceObject end ,
        OperationType =     pd.OperationType,       
        TargetServer =      case when operationtype in ('EXECUTE', 'SELECT') then pd.SourceServer else pd.TargetServer end ,
        TargetDatabase =    case when operationtype in ('EXECUTE', 'SELECT') then pd.SourceDatabase else pd.TargetDatabase end ,
        TargetSchema =      case when operationtype in ('EXECUTE', 'SELECT') then pd.SourceSchema else pd.TargetSchema end ,
        TargetObject =      case when operationtype in ('EXECUTE', 'SELECT') then pd.SourceObject else pd.TargetObject end
    into
        #ObjectParsedDependencySwitch 
    from
        Utility.LNG_ObjectParsedDependency PD
    


SELECT DISTINCT
    'ParsedOnly' AS ComparisonResult,
    p.SourceServer,
    p.SourceDatabase,
    p.SourceSchema,
    p.SourceObject,
    sol.ObjectTypeName AS SourceObjectType,
    p.OperationType,
    p.TargetServer,
    p.TargetDatabase,
    p.TargetSchema,
    p.TargetObject,
    tol.ObjectTypeName AS TargetObjectType,
    CASE WHEN od.ObjectID IS NOT NULL THEN 1 ELSE 0 END AS IsInObjectDefinitions,
    od.ObjectDefinition
FROM
    #ObjectParsedDependencySwitch p
    INNER JOIN Utility.LNG_ObjectList tol
        ON tol.ServerName = p.TargetServer
        AND tol.DatabaseName = p.TargetDatabase
        AND tol.SchemaName = p.TargetSchema
        AND tol.ObjectName = p.TargetObject
    LEFT JOIN Utility.LNG_ObjectList sol
        ON sol.ServerName = p.SourceServer
        AND sol.DatabaseName = p.SourceDatabase
        AND sol.SchemaName = p.SourceSchema
        AND sol.ObjectName = p.SourceObject
    LEFT JOIN Utility.LNG_ObjectDefinitions od
        ON od.ServerName = p.SourceServer
        AND od.DatabaseName = p.SourceDatabase
        AND od.SchemaName = p.SourceSchema
        AND od.ObjectName = p.SourceObject
WHERE NOT EXISTS (
    SELECT 1
    FROM Utility.LNG_ObjectExpressionDependency e
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
AND p.SourceObject NOT LIKE 'CK%'
AND NOT (p.SourceServer = p.TargetServer
    AND p.SourceDatabase = p.TargetDatabase
    AND p.SourceSchema = p.TargetSchema
    AND p.SourceObject = p.TargetObject)

UNION ALL

SELECT DISTINCT
    'ExpressionOnly' AS ComparisonResult,
    e.ReferencingServer,
    e.ReferencingDatabase,
    e.ReferencingSchema,
    e.ReferencingObject,
    sol.ObjectTypeName AS SourceObjectType,
    NULL AS OperationType,
    e.referenced_server_name,
    e.referenced_database_name,
    e.referenced_schema_name,
    e.referenced_entity_name,
    tol.ObjectTypeName AS TargetObjectType,
    CASE WHEN od.ObjectID IS NOT NULL THEN 1 ELSE 0 END AS IsInObjectDefinitions,
    od.ObjectDefinition
FROM
    Utility.LNG_ObjectExpressionDependency e
    INNER JOIN Utility.LNG_ObjectList tol
        ON tol.ServerName = e.referenced_server_name
        AND tol.DatabaseName = e.referenced_database_name
        AND tol.SchemaName = e.referenced_schema_name
        AND tol.ObjectName = e.referenced_entity_name
    LEFT JOIN Utility.LNG_ObjectList sol
        ON sol.ServerName = e.ReferencingServer
        AND sol.DatabaseName = e.ReferencingDatabase
        AND sol.SchemaName = e.ReferencingSchema
        AND sol.ObjectName = e.ReferencingObject
    LEFT JOIN Utility.LNG_ObjectDefinitions od
        ON od.ServerName = e.ReferencingServer
        AND od.DatabaseName = e.ReferencingDatabase
        AND od.SchemaName = e.ReferencingSchema
        AND od.ObjectName = e.ReferencingObject
WHERE NOT EXISTS (
    SELECT 1
    FROM #ObjectParsedDependencySwitch p
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
AND e.ReferencingObject NOT LIKE 'CK%'
AND e.ReferencingObjectType IS NOT NULL
AND NOT (e.ReferencingServer = e.referenced_server_name
    AND e.ReferencingDatabase = e.referenced_database_name
    AND e.ReferencingSchema = e.referenced_schema_name
    AND e.ReferencingObject = e.referenced_entity_name)

ORDER BY
    ComparisonResult,
    SourceServer,
    SourceDatabase,
    SourceSchema,
    SourceObject;