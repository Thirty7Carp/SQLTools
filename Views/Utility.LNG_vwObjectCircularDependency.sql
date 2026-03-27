CREATE VIEW Utility.LNG_vwObjectCircularDependency
AS
SELECT DISTINCT
    d1.SourceServer,
    d1.SourceDatabase,
    d1.SourceSchema,
    d1.SourceObject,
    d1.TargetServer,
    d1.TargetDatabase,
    d1.TargetSchema,
    d1.TargetObject,
    'Circular Reference Detected' AS Issue
FROM Utility.LNG_ObjectDirectDependency d1
INNER JOIN Utility.LNG_ObjectDirectDependency d2 
    ON d1.SourceServer = d2.TargetServer
    AND d1.SourceDatabase = d2.TargetDatabase
    AND d1.SourceSchema = d2.TargetSchema
    AND d1.SourceObject = d2.TargetObject
    AND d1.TargetServer = d2.SourceServer
    AND d1.TargetDatabase = d2.SourceDatabase
    AND d1.TargetSchema = d2.SourceSchema
    AND d1.TargetObject = d2.SourceObject;
