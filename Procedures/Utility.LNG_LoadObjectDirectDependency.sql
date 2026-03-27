CREATE PROCEDURE Utility.LNG_loadObjectDirectDependency
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE Utility.LNG_ObjectDirectDependency;

    INSERT INTO Utility.LNG_ObjectDirectDependency
        (SourceServer, SourceDatabase, SourceSchema, SourceObject, SourceType,
         TargetServer, TargetDatabase, TargetSchema, TargetObject, TargetType)
    
    SELECT DISTINCT
        lpd.SourceServer,
        lpd.SourceDatabase,
        lpd.SourceSchema,
        lpd.SourceObject,
        ISNULL(src.ObjectType, 'UNKNOWN'),
        lpd.TargetServer,
        lpd.TargetDatabase,
        lpd.TargetSchema,
        lpd.TargetObject,
        ISNULL(tgt.ObjectType, 'UNKNOWN')
    FROM Utility.LNG_ObjectParsedDependency lpd
    LEFT JOIN Utility.LNG_ObjectList src
        ON  src.ServerName   = lpd.SourceServer
        AND src.DatabaseName = lpd.SourceDatabase
        AND src.SchemaName   = lpd.SourceSchema
        AND src.ObjectName   = lpd.SourceObject
    LEFT JOIN Utility.LNG_ObjectList tgt
        ON  tgt.ServerName   = lpd.TargetServer
        AND tgt.DatabaseName = lpd.TargetDatabase
        AND tgt.SchemaName   = lpd.TargetSchema
        AND tgt.ObjectName   = lpd.TargetObject;
        
    IF OBJECT_ID('Utility.LNG_DynamicMerge', 'U') IS NOT NULL
    BEGIN
        INSERT INTO Utility.LNG_ObjectDirectDependency
            (SourceServer, SourceDatabase, SourceSchema, SourceObject, SourceType,
             TargetServer, TargetDatabase, TargetSchema, TargetObject, TargetType)
        SELECT DISTINCT
            SourceServerName,
            SourceDatabaseName,
            SourceSchemaName,
            SourceObjectName,
            SourceObjectType,
            TargetServerName,
            ProcessDatabaseName,
            ProcessSchemaName,
            ProcessObjectName,
            ProcessObjectType
        FROM Utility.LNG_DynamicMerge;
    END

END
GO