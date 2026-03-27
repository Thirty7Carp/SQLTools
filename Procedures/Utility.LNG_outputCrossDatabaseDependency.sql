CREATE  PROCEDURE Utility.LNG_outputCrossDatabaseDependency
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        SourceServer,
        SourceDatabase,
        SourceSchema,
        SourceObject,
        SourceType,
        TargetServer,
        TargetDatabase,
        TargetSchema,
        TargetObject,
        TargetType,
        CASE 
            WHEN SourceServer <> TargetServer THEN 'Cross-Server'
            WHEN SourceDatabase <> TargetDatabase THEN 'Cross-Database'
        END AS Scope
    FROM Utility.LNG_ObjectDirectDependency
    WHERE SourceServer <> TargetServer 
       OR SourceDatabase <> TargetDatabase
    ORDER BY Scope, SourceServer, SourceDatabase, TargetServer, TargetDatabase, SourceSchema, SourceObject;
END
GO