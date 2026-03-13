CREATE VIEW Utility.LNG_vwObjectOrphaned
AS
SELECT 
    o.ServerName,
    o.DatabaseName,
    o.SchemaName,
    o.ObjectName,
    o.ObjectTypeName,
    o.FullObjectName,
    o.CreateDate,
    o.ModifyDate
FROM Utility.LNG_ObjectList o
WHERE NOT EXISTS (
    SELECT 1 FROM Utility.LNG_ObjectDirectDependency od
    WHERE (od.SourceServer = o.ServerName AND od.SourceDatabase = o.DatabaseName AND od.SourceSchema = o.SchemaName AND od.SourceObject = o.ObjectName)
       OR (od.TargetServer = o.ServerName AND od.TargetDatabase = o.DatabaseName AND od.TargetSchema = o.SchemaName AND od.TargetObject = o.ObjectName)
);