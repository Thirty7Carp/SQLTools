CREATE PROCEDURE Utility.LNG_updateObjectParsedDependency_ObjectCleanse

AS
BEGIN
    SET NOCOUNT ON;

    
    -- Remove dependencies where target object does not exist in LineageObjectList
    DELETE lpd
    FROM Utility.LNG_ObjectParsedDependency lpd
    LEFT JOIN Utility.LNG_ObjectList lol
        ON  lpd.TargetServer   = lol.ServerName
        AND lpd.TargetDatabase = lol.DatabaseName
        AND lpd.TargetSchema   = lol.SchemaName
        AND lpd.TargetObject   = lol.ObjectName
    WHERE
        lpd.TargetServer = @@SERVERNAME
        AND lol.ObjectName IS NULL;
    
    -- Remove duplicate rows keeping the lowest ParsedDependencyID for each unique combination
    DELETE FROM Utility.LNG_ObjectParsedDependency
    WHERE ParsedDependencyID NOT IN 
        (
        SELECT MIN(ParsedDependencyID)
        FROM Utility.LNG_ObjectParsedDependency
        GROUP BY
            SourceServer,
            SourceDatabase,
            SourceSchema,
            SourceObject,
            OperationType,
            TargetServer,
            TargetDatabase,
            TargetSchema,
            TargetObject
            )

    -- Switch the source and target for Operation Types That call on another item without changing it
    UPDATE Utility.LNG_ObjectParsedDependency
    SET
        SourceServer   = TargetServer,
        SourceDatabase = TargetDatabase,
        SourceSchema   = TargetSchema,
        SourceObject   = TargetObject,
        TargetServer   = SourceServer,
        TargetDatabase = SourceDatabase,
        TargetSchema   = SourceSchema,
        TargetObject   = SourceObject
    WHERE 
        OperationType IN ('SELECT', 'EXECUTE')
    
END
GO