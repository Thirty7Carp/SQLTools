CREATE VIEW Utility.vwLineageObjectDirectDependency
AS
SELECT 
    od.SourceServer + '.' + od.SourceDatabase + '.' + od.SourceSchema + '.' + od.SourceObject AS SourceFullName,
    od.SourceServer,
    od.SourceDatabase,
    od.SourceSchema,
    od.SourceObject,
    od.SourceType,
    od.TargetServer + '.' + od.TargetDatabase + '.' + od.TargetSchema + '.' + od.TargetObject AS TargetFullName,
    od.TargetServer,
    od.TargetDatabase,
    od.TargetSchema,
    od.TargetObject,
    od.TargetType,
    od.DependencyType,
    od.IsSchemabound,
    CASE 
        WHEN od.SourceServer <> od.TargetServer THEN 'Cross Server'
        WHEN od.SourceDatabase <> od.TargetDatabase THEN 'Cross Database'
        ELSE 'Same Database'
    END AS DependencyScope
FROM Utility.LineageObjectDirectDependency od;
GO