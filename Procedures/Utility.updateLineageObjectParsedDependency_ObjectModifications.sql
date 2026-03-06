CREATE PROCEDURE Utility.updateLineageObjectParsedDependency_ObjectCleanse

AS
BEGIN
    SET NOCOUNT ON;

    
    -- Remove dependencies where target object does not exist in LineageObjectList
    DELETE lpd
    FROM Utility.LineageObjectParsedDependency lpd
    LEFT JOIN Utility.LineageObjectList lol
        ON  lpd.TargetServer   = lol.ServerName
        AND lpd.TargetDatabase = lol.DatabaseName
        AND lpd.TargetSchema   = lol.SchemaName
        AND lpd.TargetObject   = lol.ObjectName
    WHERE
        lpd.TargetServer = @@SERVERNAME
        AND lol.ObjectName IS NULL;
    
    -- Remove duplicate rows keeping the lowest ParsedDependencyID for each unique combination
    DELETE FROM Utility.LineageObjectParsedDependency
    WHERE ParsedDependencyID NOT IN 
        (
        SELECT MIN(ParsedDependencyID)
        FROM Utility.LineageObjectParsedDependency
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
    UPDATE Utility.LineageObjectParsedDependency
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