IF OBJECT_ID(N'Utility.LNG_vwObjectSummary', N'V') IS NULL
BEGIN
    EXEC('CREATE VIEW Utility.LNG_vwObjectSummary AS SELECT 1 AS placeholder');
END
GO

ALTER VIEW Utility.LNG_vwObjectSummary
AS
SELECT 
    o.ServerName,
    o.DatabaseName,
    o.SchemaName,
    o.ObjectName,
    o.ObjectTypeName,
    o.FullObjectName,
    ISNULL(deps_out.DependsOnCount, 0) AS DependsOnCount,
    ISNULL(deps_in.DependedByCount, 0) AS DependedByCount,
    ISNULL(deps_out.DependsOnCount, 0) + ISNULL(deps_in.DependedByCount, 0) AS TotalDependencies,
    o.CreateDate,
    o.ModifyDate
FROM Utility.LNG_ObjectList o
LEFT JOIN (
    SELECT SourceServer, SourceDatabase, SourceSchema, SourceObject, COUNT(*) AS DependsOnCount
    FROM Utility.LNG_ObjectDirectDependency
    GROUP BY SourceServer, SourceDatabase, SourceSchema, SourceObject
) deps_out ON o.ServerName = deps_out.SourceServer 
    AND o.DatabaseName = deps_out.SourceDatabase 
    AND o.SchemaName = deps_out.SourceSchema 
    AND o.ObjectName = deps_out.SourceObject
LEFT JOIN (
    SELECT TargetServer, TargetDatabase, TargetSchema, TargetObject, COUNT(*) AS DependedByCount
    FROM Utility.LNG_ObjectDirectDependency
    GROUP BY TargetServer, TargetDatabase, TargetSchema, TargetObject
) deps_in ON o.ServerName = deps_in.TargetServer 
    AND o.DatabaseName = deps_in.TargetDatabase 
    AND o.SchemaName = deps_in.TargetSchema 
    AND o.ObjectName = deps_in.TargetObject;
GO