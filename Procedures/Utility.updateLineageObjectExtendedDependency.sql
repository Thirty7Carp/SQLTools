
CREATE PROCEDURE Utility.loadLineageObjectExtendedDependency
    @MaxLevels INT = 15  -- Maximum recursion depth
AS
BEGIN
    SET NOCOUNT ON;
    
    TRUNCATE TABLE Utility.LineageObjectExtendedDependency;
    
    -- Build downstream lineage (what depends on what)
    ;WITH RecursiveDependencies AS (
        -- Base case: direct dependencies
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
        FROM Utility.LineageObjectDirectDependency od
        WHERE NOT EXISTS (
            SELECT 1 FROM Utility.LineageObjectExclusions le
            WHERE le.IsActive = 1
                AND (le.ServerName IS NULL OR le.ServerName = od.TargetServer)
                AND (le.DatabaseName IS NULL OR le.DatabaseName = od.TargetDatabase)
                AND (le.SchemaName IS NULL OR le.SchemaName = od.TargetSchema)
                AND od.TargetObject LIKE le.ObjectName
        )
        
        UNION ALL
        
        -- Recursive case: follow the chain
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
        INNER JOIN Utility.LineageObjectDirectDependency od 
            ON rd.DependentServer = od.SourceServer
            AND rd.DependentDatabase = od.SourceDatabase
            AND rd.DependentSchema = od.SourceSchema
            AND rd.DependentObject = od.SourceObject
        WHERE rd.LineageLevel < @MaxLevels
            -- Prevent circular references
            AND rd.LineagePath NOT LIKE '%' + od.TargetServer + '.' + od.TargetDatabase + '.' + od.TargetSchema + '.' + od.TargetObject + '%'
            -- Exclude objects in exclusion list
            AND NOT EXISTS (
                SELECT 1 FROM Utility.LineageObjectExclusions le
                WHERE le.IsActive = 1
                    AND (le.ServerName IS NULL OR le.ServerName = od.TargetServer)
                    AND (le.DatabaseName IS NULL OR le.DatabaseName = od.TargetDatabase)
                    AND (le.SchemaName IS NULL OR le.SchemaName = od.TargetSchema)
                    AND od.TargetObject LIKE le.ObjectName
            )
    )
    INSERT INTO Utility.LineageObjectExtendedDependency 
        (RootServer, RootDatabase, RootSchema, RootObject, RootObjectType,
         DependentServer, DependentDatabase, DependentSchema, DependentObject, DependentObjectType,
         LineagePath, LineageLevel, LineageDirection)
    SELECT DISTINCT
        RootServer, RootDatabase, RootSchema, RootObject, RootObjectType,
        DependentServer, DependentDatabase, DependentSchema, DependentObject, DependentObjectType,
        LineagePath, LineageLevel, 'Downstream'
    FROM RecursiveDependencies
    OPTION (MAXRECURSION 0);
    
    -- Build upstream lineage (what an object depends on)
    ;WITH RecursiveUpstream AS (
        -- Base case: direct dependencies (reversed)
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
        FROM Utility.LineageObjectDirectDependency od
        WHERE NOT EXISTS (
            SELECT 1 FROM Utility.LineageObjectExclusions le
            WHERE le.IsActive = 1
                AND (le.ServerName IS NULL OR le.ServerName = od.SourceServer)
                AND (le.DatabaseName IS NULL OR le.DatabaseName = od.SourceDatabase)
                AND (le.SchemaName IS NULL OR le.SchemaName = od.SourceSchema)
                AND od.SourceObject LIKE le.ObjectName
        )
        
        UNION ALL
        
        -- Recursive case: follow upstream
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
        INNER JOIN Utility.LineageObjectDirectDependency od 
            ON ru.DependentServer = od.TargetServer
            AND ru.DependentDatabase = od.TargetDatabase
            AND ru.DependentSchema = od.TargetSchema
            AND ru.DependentObject = od.TargetObject
        WHERE ru.LineageLevel < @MaxLevels
            AND ru.LineagePath NOT LIKE '%' + od.SourceServer + '.' + od.SourceDatabase + '.' + od.SourceSchema + '.' + od.SourceObject + '%'
            -- Exclude objects in exclusion list
            AND NOT EXISTS (
                SELECT 1 FROM Utility.LineageObjectExclusions le
                WHERE le.IsActive = 1
                    AND (le.ServerName IS NULL OR le.ServerName = od.SourceServer)
                    AND (le.DatabaseName IS NULL OR le.DatabaseName = od.SourceDatabase)
                    AND (le.SchemaName IS NULL OR le.SchemaName = od.SourceSchema)
                    AND od.SourceObject LIKE le.ObjectName
            )
    )
    INSERT INTO Utility.LineageObjectExtendedDependency 
        (RootServer, RootDatabase, RootSchema, RootObject, RootObjectType,
         DependentServer, DependentDatabase, DependentSchema, DependentObject, DependentObjectType,
         LineagePath, LineageLevel, LineageDirection)
    SELECT DISTINCT
        RootServer, RootDatabase, RootSchema, RootObject, RootObjectType,
        DependentServer, DependentDatabase, DependentSchema, DependentObject, DependentObjectType,
        LineagePath, LineageLevel, 'Upstream'
    FROM RecursiveUpstream
    OPTION (MAXRECURSION 0);
    
    SELECT COUNT(*) AS TotalLineagePathsCaptured FROM Utility.LineageObjectExtendedDependency;
END
GO