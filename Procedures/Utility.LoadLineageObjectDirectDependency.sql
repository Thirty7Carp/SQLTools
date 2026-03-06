CREATE PROCEDURE Utility.loadLineageObjectDirectDependency
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE Utility.LineageObjectDirectDependency;

    INSERT INTO Utility.LineageObjectDirectDependency
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
    FROM Utility.LineageObjectParsedDependency lpd
    LEFT JOIN Utility.LineageObjectList src
        ON  src.ServerName   = lpd.SourceServer
        AND src.DatabaseName = lpd.SourceDatabase
        AND src.SchemaName   = lpd.SourceSchema
        AND src.ObjectName   = lpd.SourceObject
    LEFT JOIN Utility.LineageObjectList tgt
        ON  tgt.ServerName   = lpd.TargetServer
        AND tgt.DatabaseName = lpd.TargetDatabase
        AND tgt.SchemaName   = lpd.TargetSchema
        AND tgt.ObjectName   = lpd.TargetObject

    UNION ALL

    select
            SourceServer  = SourceServerName
            , SourceDatabase = SourceDatabaseName
            , SourceSchema = SourceSchemaName
            , SourceObject = SourceObjectName
            , SourceType = SourceObjectType
            , TargetServer = TargetServerName
            , TatargetDatabase = ProcessDatabaseName
            , TargetSchema = ProcessSchemaName
            , TargetObject = ProcessObjectName
            , TargetType = ProcessObjectType
        from
	        SQLTools.Utility.DynamicMerge

END
GO