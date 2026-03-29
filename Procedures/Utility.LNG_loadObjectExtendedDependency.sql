IF OBJECT_ID('Utility.LNG_loadObjectExtendedDependency', 'P') IS NOT NULL
    DROP PROCEDURE Utility.LNG_loadObjectExtendedDependency;

GO

CREATE PROCEDURE Utility.LNG_loadObjectExtendedDependency
    @MaxLevels INT = 30  -- Maximum recursion depth
AS
BEGIN
    SET NOCOUNT ON;
    
    TRUNCATE TABLE Utility.LNG_ObjectExtendedDependency;
    TRUNCATE TABLE Utility.LNG_ObjectExtendedDependencyLimit;
    
 
    ;WITH RecursiveDependencies AS (
        SELECT 
            SourceServer AS RootServer,
            SourceDatabase AS RootDatabase,
            SourceSchema AS RootSchema,
            SourceObject AS RootObject,
            SourceType AS RootObjectType,
            TargetServer AS DependentServer,
            TargetDatabase AS DependentDatabase,
            TargetSchema AS DependentSchema,
            TargetObject AS DependentObject,
            TargetType AS DependentObjectType,
            CAST(SourceServer + '.' + SourceDatabase + '.' + SourceSchema + '.' + SourceObject + ' -> ' + 
                 TargetServer + '.' + TargetDatabase + '.' + TargetSchema + '.' + TargetObject AS NVARCHAR(MAX)) AS LineagePath,
            1 AS LineageLevel
        FROM Utility.LNG_ObjectDirectDependency od
        WHERE NOT EXISTS (
            SELECT 1 FROM Utility.LNG_ObjectExclusions le
            WHERE le.IsActive = 1
                AND (le.ServerName IS NULL OR le.ServerName = od.TargetServer)
                AND (le.DatabaseName IS NULL OR le.DatabaseName = od.TargetDatabase)
                AND (le.SchemaName IS NULL OR le.SchemaName = od.TargetSchema)
                AND od.TargetObject LIKE le.ObjectName
        )
        
        UNION ALL
        
        
        SELECT 
            rd.RootServer,
            rd.RootDatabase,
            rd.RootSchema,
            rd.RootObject,
            rd.RootObjectType,
            od.TargetServer,
            od.TargetDatabase,
            od.TargetSchema,
            od.TargetObject,
            od.TargetType,
            CAST(rd.LineagePath + ' -> ' + 
                 od.TargetServer + '.' + od.TargetDatabase + '.' + od.TargetSchema + '.' + od.TargetObject AS NVARCHAR(MAX)),
            rd.LineageLevel + 1
        FROM RecursiveDependencies rd
        INNER JOIN Utility.LNG_ObjectDirectDependency od 
            ON rd.DependentServer = od.SourceServer
            AND rd.DependentDatabase = od.SourceDatabase
            AND rd.DependentSchema = od.SourceSchema
            AND rd.DependentObject = od.SourceObject
        WHERE rd.LineageLevel < @MaxLevels
            -- Prevent circular references
            AND rd.LineagePath NOT LIKE '%' + od.TargetServer + '.' + od.TargetDatabase + '.' + od.TargetSchema + '.' + od.TargetObject + '%'
            AND NOT EXISTS (
                SELECT 1 FROM Utility.LNG_ObjectExclusions le
                WHERE le.IsActive = 1
                    AND (le.ServerName IS NULL OR le.ServerName = od.TargetServer)
                    AND (le.DatabaseName IS NULL OR le.DatabaseName = od.TargetDatabase)
                    AND (le.SchemaName IS NULL OR le.SchemaName = od.TargetSchema)
                    AND od.TargetObject LIKE le.ObjectName
            )
    )
    INSERT INTO Utility.LNG_ObjectExtendedDependency 
        (RootServer, RootDatabase, RootSchema, RootObject, RootObjectType,
         DependentServer, DependentDatabase, DependentSchema, DependentObject, DependentObjectType,
         LineagePath, LineageLevel, LineageDirection)
    SELECT DISTINCT
        RootServer, RootDatabase, RootSchema, RootObject, RootObjectType,
        DependentServer, DependentDatabase, DependentSchema, DependentObject, DependentObjectType,
        LineagePath, LineageLevel, 'Downstream'
    FROM RecursiveDependencies
    OPTION (MAXRECURSION 0);

    -- Record downstream objects that hit the max level limit
    INSERT INTO Utility.LNG_ObjectExtendedDependencyLimit
        (RootServer, RootDatabase, RootSchema, RootObject, LineageDirection, MaxLevel)
    SELECT DISTINCT
        RootServer, RootDatabase, RootSchema, RootObject, 'Downstream', @MaxLevels
    FROM Utility.LNG_ObjectExtendedDependency
    WHERE LineageLevel = @MaxLevels
        AND LineageDirection = 'Downstream';
    
    -- Build upstream lineage (what an object depends on)
    ;WITH RecursiveUpstream AS (
       
        SELECT 
            TargetServer AS RootServer,
            TargetDatabase AS RootDatabase,
            TargetSchema AS RootSchema,
            TargetObject AS RootObject,
            TargetType AS RootObjectType,
            SourceServer AS DependentServer,
            SourceDatabase AS DependentDatabase,
            SourceSchema AS DependentSchema,
            SourceObject AS DependentObject,
            SourceType AS DependentObjectType,
            CAST(TargetServer + '.' + TargetDatabase + '.' + TargetSchema + '.' + TargetObject + ' <- ' + 
                 SourceServer + '.' + SourceDatabase + '.' + SourceSchema + '.' + SourceObject AS NVARCHAR(MAX)) AS LineagePath,
            1 AS LineageLevel
        FROM Utility.LNG_ObjectDirectDependency od
        WHERE NOT EXISTS (
            SELECT 1 FROM Utility.LNG_ObjectExclusions le
            WHERE le.IsActive = 1
                AND (le.ServerName IS NULL OR le.ServerName = od.SourceServer)
                AND (le.DatabaseName IS NULL OR le.DatabaseName = od.SourceDatabase)
                AND (le.SchemaName IS NULL OR le.SchemaName = od.SourceSchema)
                AND od.SourceObject LIKE le.ObjectName
        )
        
        UNION ALL
        
   
        SELECT 
            ru.RootServer,
            ru.RootDatabase,
            ru.RootSchema,
            ru.RootObject,
            ru.RootObjectType,
            od.SourceServer,
            od.SourceDatabase,
            od.SourceSchema,
            od.SourceObject,
            od.SourceType,
            CAST(ru.LineagePath + ' <- ' + 
                 od.SourceServer + '.' + od.SourceDatabase + '.' + od.SourceSchema + '.' + od.SourceObject AS NVARCHAR(MAX)),
            ru.LineageLevel + 1
        FROM RecursiveUpstream ru
        INNER JOIN Utility.LNG_ObjectDirectDependency od 
            ON ru.DependentServer = od.TargetServer
            AND ru.DependentDatabase = od.TargetDatabase
            AND ru.DependentSchema = od.TargetSchema
            AND ru.DependentObject = od.TargetObject
        WHERE ru.LineageLevel < @MaxLevels
            AND ru.LineagePath NOT LIKE '%' + od.SourceServer + '.' + od.SourceDatabase + '.' + od.SourceSchema + '.' + od.SourceObject + '%'
            AND NOT EXISTS (
                SELECT 1 FROM Utility.LNG_ObjectExclusions le
                WHERE le.IsActive = 1
                    AND (le.ServerName IS NULL OR le.ServerName = od.SourceServer)
                    AND (le.DatabaseName IS NULL OR le.DatabaseName = od.SourceDatabase)
                    AND (le.SchemaName IS NULL OR le.SchemaName = od.SourceSchema)
                    AND od.SourceObject LIKE le.ObjectName
            )
    )
    INSERT INTO Utility.LNG_ObjectExtendedDependency 
        (RootServer, RootDatabase, RootSchema, RootObject, RootObjectType,
         DependentServer, DependentDatabase, DependentSchema, DependentObject, DependentObjectType,
         LineagePath, LineageLevel, LineageDirection)
    SELECT DISTINCT
        RootServer, RootDatabase, RootSchema, RootObject, RootObjectType,
        DependentServer, DependentDatabase, DependentSchema, DependentObject, DependentObjectType,
        LineagePath, LineageLevel, 'Upstream'
    FROM RecursiveUpstream
    OPTION (MAXRECURSION 0);

    -- Record upstream objects that hit the max level limit
    INSERT INTO Utility.LNG_ObjectExtendedDependencyLimit
        (RootServer, RootDatabase, RootSchema, RootObject, LineageDirection, MaxLevel)
    SELECT DISTINCT
        RootServer, RootDatabase, RootSchema, RootObject, 'Upstream', @MaxLevels
    FROM Utility.LNG_ObjectExtendedDependency
    WHERE LineageLevel = @MaxLevels
        AND LineageDirection = 'Upstream';
    
    SELECT COUNT(*) AS TotalLineagePathsCaptured FROM Utility.LNG_ObjectExtendedDependency;
END
GO