

-- View: Circular dependencies detection
CREATE OR ALTER VIEW Utility.vwLineageObjectCircularDependency
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
FROM Utility.LineageObjectDirectDependency d1
INNER JOIN Utility.LineageObjectDirectDependency d2 
    ON d1.SourceServer = d2.TargetServer
    AND d1.SourceDatabase = d2.TargetDatabase
    AND d1.SourceSchema = d2.TargetSchema
    AND d1.SourceObject = d2.TargetObject
    AND d1.TargetServer = d2.SourceServer
    AND d1.TargetDatabase = d2.SourceDatabase
    AND d1.TargetSchema = d2.SourceSchema
    AND d1.TargetObject = d2.SourceObject;
GO

-- View: Orphaned objects (no dependencies in or out)
CREATE OR ALTER VIEW Utility.vwLineageObjectOrphaned
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
FROM Utility.LineageObjectList o
WHERE NOT EXISTS (
    SELECT 1 FROM Utility.LineageObjectDirectDependency od
    WHERE (od.SourceServer = o.ServerName AND od.SourceDatabase = o.DatabaseName AND od.SourceSchema = o.SchemaName AND od.SourceObject = o.ObjectName)
       OR (od.TargetServer = o.ServerName AND od.TargetDatabase = o.DatabaseName AND od.TargetSchema = o.SchemaName AND od.TargetObject = o.ObjectName)
);
GO

-- ============================================================================
-- 8. UTILITY PROCEDURES FOR SPECIFIC QUERIES
-- ============================================================================

-- Get all dependencies for a specific object
CREATE OR ALTER PROCEDURE Utility.outputLineageObjectDependency
    @ServerName NVARCHAR(128) = NULL,  -- NULL defaults to current server
    @DatabaseName NVARCHAR(128),
    @SchemaName NVARCHAR(128),
    @ObjectName NVARCHAR(128),
    @Direction NVARCHAR(20) = 'Both'  -- 'Upstream', 'Downstream', or 'Both'
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default to current server if not specified
    IF @ServerName IS NULL
        SET @ServerName = @@SERVERNAME;
    
    IF @Direction IN ('Downstream', 'Both')
    BEGIN
        PRINT '=== DOWNSTREAM DEPENDENCIES (What depends on this object) ===';
        SELECT 
            LineageLevel,
            DependentServer,
            DependentDatabase,
            DependentSchema,
            DependentObject,
            DependentObjectType,
            LineagePath
        FROM Utility.LineageObjectExtendedDependency
        WHERE RootServer = @ServerName
            AND RootDatabase = @DatabaseName
            AND RootSchema = @SchemaName
            AND RootObject = @ObjectName
            AND LineageDirection = 'Downstream'
        ORDER BY LineageLevel, DependentServer, DependentDatabase, DependentSchema, DependentObject;
    END
    
    IF @Direction IN ('Upstream', 'Both')
    BEGIN
        PRINT '=== UPSTREAM DEPENDENCIES (What this object depends on) ===';
        SELECT 
            LineageLevel,
            DependentServer,
            DependentDatabase,
            DependentSchema,
            DependentObject,
            DependentObjectType,
            LineagePath
        FROM Utility.LineageObjectExtendedDependency
        WHERE RootServer = @ServerName
            AND RootDatabase = @DatabaseName
            AND RootSchema = @SchemaName
            AND RootObject = @ObjectName
            AND LineageDirection = 'Upstream'
        ORDER BY LineageLevel, DependentServer, DependentDatabase, DependentSchema, DependentObject;
    END
END
GO

-- Get impact analysis for a specific object
CREATE OR ALTER PROCEDURE Utility.outputLineageImpactAnalysis
    @ServerName NVARCHAR(128) = NULL,  -- NULL defaults to current server
    @DatabaseName NVARCHAR(128),
    @SchemaName NVARCHAR(128),
    @ObjectName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default to current server if not specified
    IF @ServerName IS NULL
        SET @ServerName = @@SERVERNAME;
    
    PRINT '=== IMPACT ANALYSIS: ' + @ServerName + '.' + @DatabaseName + '.' + @SchemaName + '.' + @ObjectName + ' ===';
    
    SELECT 
        LineageLevel,
        COUNT(DISTINCT DependentServer + '.' + DependentDatabase + '.' + DependentSchema + '.' + DependentObject) AS AffectedObjectCount,
        STRING_AGG(DependentServer + '.' + DependentDatabase + '.' + DependentSchema + '.' + DependentObject, ', ') WITHIN GROUP (ORDER BY DependentServer, DependentDatabase, DependentSchema, DependentObject) AS AffectedObjects
    FROM Utility.LineageObjectExtendedDependency
    WHERE RootServer = @ServerName
        AND RootDatabase = @DatabaseName
        AND RootSchema = @SchemaName
        AND RootObject = @ObjectName
        AND LineageDirection = 'Downstream'
    GROUP BY LineageLevel
    ORDER BY LineageLevel;
    
    -- Summary
    SELECT 
        COUNT(DISTINCT DependentServer + '.' + DependentDatabase + '.' + DependentSchema + '.' + DependentObject) AS TotalAffectedObjects,
        MAX(LineageLevel) AS MaxDependencyDepth
    FROM Utility.LineageObjectExtendedDependency
    WHERE RootServer = @ServerName
        AND RootDatabase = @DatabaseName
        AND RootSchema = @SchemaName
        AND RootObject = @ObjectName
        AND LineageDirection = 'Downstream';
END
GO

-- Get all cross-database and cross-server dependencies
CREATE OR ALTER PROCEDURE Utility.outputLineageCrossDatabaseDependency
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
        DependencyType,
        CASE 
            WHEN SourceServer <> TargetServer THEN 'Cross-Server'
            WHEN SourceDatabase <> TargetDatabase THEN 'Cross-Database'
        END AS Scope
    FROM Utility.LineageObjectDirectDependency
    WHERE SourceServer <> TargetServer 
       OR SourceDatabase <> TargetDatabase
    ORDER BY Scope, SourceServer, SourceDatabase, TargetServer, TargetDatabase, SourceSchema, SourceObject;
END
GO

-- ============================================================================
-- 9. EXCLUSION MANAGEMENT PROCEDURES
-- ============================================================================

-- Add a database exclusion
CREATE OR ALTER PROCEDURE Utility.alterLineageDatabaseExclusionsAdd
    @ServerName NVARCHAR(128) = NULL,
    @DatabaseName NVARCHAR(128),
    @ExclusionReason NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO Utility.LineageDatabaseExclusions (ServerName, DatabaseName, ExclusionReason)
    VALUES (@ServerName, @DatabaseName, @ExclusionReason);
    
    PRINT 'Database exclusion added: ' + ISNULL(@ServerName + '.', '') + @DatabaseName;
END
GO

-- Remove a database exclusion
CREATE OR ALTER PROCEDURE Utility.alterLineageDatabaseExclusionsRemove
    @ExclusionID BIGINT = NULL,
    @ServerName NVARCHAR(128) = NULL,
    @DatabaseName NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @ExclusionID IS NOT NULL
    BEGIN
        DELETE FROM Utility.LineageDatabaseExclusions WHERE ExclusionID = @ExclusionID;
        PRINT 'Database exclusion removed (ID: ' + CAST(@ExclusionID AS VARCHAR(10)) + ')';
    END
    ELSE
    BEGIN
        DELETE FROM Utility.LineageDatabaseExclusions
        WHERE (ServerName = @ServerName OR (ServerName IS NULL AND @ServerName IS NULL))
            AND DatabaseName = @DatabaseName;
        
        PRINT 'Database exclusion removed: ' + ISNULL(@ServerName + '.', '') + @DatabaseName;
    END
END
GO

-- View all database exclusions
CREATE OR ALTER PROCEDURE Utility.outputLineageDatabaseExclusions
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ExclusionID,
        ServerName,
        DatabaseName,
        ExclusionReason,
        IsActive,
        CreatedDate,
        CreatedBy
    FROM Utility.LineageDatabaseExclusions
    ORDER BY ServerName, DatabaseName;
END
GO

-- Add default system database exclusions
CREATE OR ALTER PROCEDURE Utility.alterLineageDatabaseExclusionsAddDefaults
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Add standard system databases
    INSERT INTO Utility.LineageDatabaseExclusions (DatabaseName, ExclusionReason)
    SELECT 'master', 'System database'
    WHERE NOT EXISTS (SELECT 1 FROM Utility.LineageDatabaseExclusions WHERE DatabaseName = 'master');
    
    INSERT INTO Utility.LineageDatabaseExclusions (DatabaseName, ExclusionReason)
    SELECT 'tempdb', 'System database'
    WHERE NOT EXISTS (SELECT 1 FROM Utility.LineageDatabaseExclusions WHERE DatabaseName = 'tempdb');
    
    INSERT INTO Utility.LineageDatabaseExclusions (DatabaseName, ExclusionReason)
    SELECT 'model', 'System database'
    WHERE NOT EXISTS (SELECT 1 FROM Utility.LineageDatabaseExclusions WHERE DatabaseName = 'model');
    
    INSERT INTO Utility.LineageDatabaseExclusions (DatabaseName, ExclusionReason)
    SELECT 'msdb', 'System database'
    WHERE NOT EXISTS (SELECT 1 FROM Utility.LineageDatabaseExclusions WHERE DatabaseName = 'msdb');
    
    PRINT 'Default database exclusions added (master, tempdb, model, msdb)';
END
GO

-- Add an object lineage exclusion
CREATE OR ALTER PROCEDURE Utility.alterLineageObjectExclusionsAdd
    @ServerName NVARCHAR(128) = NULL,
    @DatabaseName NVARCHAR(128) = NULL,
    @SchemaName NVARCHAR(128) = NULL,
    @ObjectName NVARCHAR(128),
    @ExclusionReason NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO Utility.LineageObjectExclusions (ServerName, DatabaseName, SchemaName, ObjectName, ExclusionReason)
    VALUES (@ServerName, @DatabaseName, @SchemaName, @ObjectName, @ExclusionReason);
    
    PRINT 'Exclusion added for: ' + ISNULL(@ServerName + '.', '') + ISNULL(@DatabaseName + '.', '') + 
          ISNULL(@SchemaName + '.', '') + @ObjectName;
END
GO

-- Remove an object lineage exclusion
CREATE OR ALTER PROCEDURE Utility.alterLineageObjectExclusionsRemove
    @ExclusionID BIGINT = NULL,
    @ServerName NVARCHAR(128) = NULL,
    @DatabaseName NVARCHAR(128) = NULL,
    @SchemaName NVARCHAR(128) = NULL,
    @ObjectName NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @ExclusionID IS NOT NULL
    BEGIN
        DELETE FROM Utility.LineageObjectExclusions WHERE ExclusionID = @ExclusionID;
        PRINT 'Exclusion removed (ID: ' + CAST(@ExclusionID AS VARCHAR(10)) + ')';
    END
    ELSE
    BEGIN
        DELETE FROM Utility.LineageObjectExclusions
        WHERE (ServerName = @ServerName OR (ServerName IS NULL AND @ServerName IS NULL))
            AND (DatabaseName = @DatabaseName OR (DatabaseName IS NULL AND @DatabaseName IS NULL))
            AND (SchemaName = @SchemaName OR (SchemaName IS NULL AND @SchemaName IS NULL))
            AND ObjectName = @ObjectName;
        
        PRINT 'Exclusion removed for: ' + ISNULL(@ServerName + '.', '') + ISNULL(@DatabaseName + '.', '') + 
              ISNULL(@SchemaName + '.', '') + @ObjectName;
    END
END
GO

-- View all exclusions
CREATE OR ALTER PROCEDURE Utility.outputLineageObjectExclusions
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ExclusionID,
        ServerName,
        DatabaseName,
        SchemaName,
        ObjectName,
        ExclusionReason,
        IsActive,
        CreatedDate,
        CreatedBy
    FROM Utility.LineageObjectExclusions
    ORDER BY ServerName, DatabaseName, SchemaName, ObjectName;
END
GO

-- ============================================================================
-- 10. MASTER PROCEDURE: Run Complete Lineage Analysis
-- ============================================================================

CREATE OR ALTER PROCEDURE Utility.batchLineageAnalysis
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @ObjectCount INT, @DependencyCount INT, @LineageCount INT;
    
    PRINT '=== STARTING COMPLETE LINEAGE ANALYSIS ===';
    PRINT 'Start Time: ' + CONVERT(VARCHAR(30), @StartTime, 121);
    PRINT '';
    
    -- Step 1: Capture all objects
    PRINT 'Step 1: Capturing all database objects...';
    EXEC Utility.loadLineageObjectList;
    SELECT @ObjectCount = COUNT(*) FROM Utility.LineageObjectList;
    PRINT 'Objects captured: ' + CAST(@ObjectCount AS VARCHAR(10));
    PRINT '';
    
    -- Step 2: Capture all dependencies
    PRINT 'Step 2: Capturing all dependencies...';
    EXEC Utility.loadLineageObjectDirectDependency;
    SELECT @DependencyCount = COUNT(*) FROM Utility.LineageObjectDirectDependency;
    PRINT 'Dependencies captured: ' + CAST(@DependencyCount AS VARCHAR(10));
    PRINT '';
    
    -- Step 3: Build complete lineage
    PRINT 'Step 3: Building complete lineage...';
    EXEC Utility.updateLineageObjectExtendedDependency @MaxLevels = 10;
    SELECT @LineageCount = COUNT(*) FROM Utility.LineageObjectExtendedDependency;
    PRINT 'Lineage paths built: ' + CAST(@LineageCount AS VARCHAR(10));
    PRINT '';
    
    -- Step 4: Capture column-level lineage
    PRINT 'Step 4: Capturing column-level lineage...';
    EXEC Utility.loadLineageColumnDependency;
    DECLARE @ColumnLineageCount INT;
    SELECT @ColumnLineageCount = COUNT(*) FROM Utility.LineageColumnDependency;
    PRINT 'Column lineage captured: ' + CAST(@ColumnLineageCount AS VARCHAR(10));
    PRINT '';
    
    -- Summary statistics
    PRINT '=== SUMMARY ===';
    PRINT 'Total Objects: ' + CAST(@ObjectCount AS VARCHAR(10));
    PRINT 'Total Direct Dependencies: ' + CAST(@DependencyCount AS VARCHAR(10));
    PRINT 'Total Lineage Paths: ' + CAST(@LineageCount AS VARCHAR(10));
    PRINT 'Total Column Lineage: ' + CAST(@ColumnLineageCount AS VARCHAR(10));
    PRINT 'Execution Time: ' + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS VARCHAR(10)) + ' seconds';
    PRINT '';
    
    -- Object type breakdown
    PRINT '=== OBJECT TYPE BREAKDOWN ===';
    SELECT ObjectTypeName, COUNT(*) AS Count
    FROM Utility.LineageObjectList
    GROUP BY ObjectTypeName
    ORDER BY COUNT(*) DESC;
    
    -- Database breakdown
    PRINT '';
    PRINT '=== DATABASE BREAKDOWN ===';
    SELECT DatabaseName, COUNT(*) AS ObjectCount
    FROM Utility.LineageObjectList
    GROUP BY DatabaseName
    ORDER BY COUNT(*) DESC;
END
GO

-- ============================================================================
-- 10. ADDITIONAL UTILITY PROCEDURES
-- ============================================================================

-- Get column lineage for a specific column
CREATE OR ALTER PROCEDURE Utility.outputLineageColumnDependency
    @ServerName NVARCHAR(128) = NULL,  -- NULL defaults to current server
    @DatabaseName NVARCHAR(128),
    @SchemaName NVARCHAR(128),
    @ObjectName NVARCHAR(128),
    @ColumnName NVARCHAR(128) = NULL  -- NULL = all columns
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default to current server if not specified
    IF @ServerName IS NULL
        SET @ServerName = @@SERVERNAME;
    
    IF @ColumnName IS NULL
    BEGIN
        -- Show all columns for the object
        SELECT 
            SourceServer,
            SourceDatabase,
            SourceSchema,
            SourceObject,
            SourceColumn,
            TargetServer,
            TargetDatabase,
            TargetSchema,
            TargetObject,
            TargetColumn,
            TransformationType
        FROM Utility.LineageColumnDependency
        WHERE SourceServer = @ServerName
            AND SourceDatabase = @DatabaseName
            AND SourceSchema = @SchemaName
            AND SourceObject = @ObjectName
        ORDER BY SourceColumn, TargetServer, TargetObject, TargetColumn;
    END
    ELSE
    BEGIN
        -- Show lineage for specific column
        SELECT 
            SourceServer,
            SourceDatabase,
            SourceSchema,
            SourceObject,
            SourceColumn,
            TargetServer,
            TargetDatabase,
            TargetSchema,
            TargetObject,
            TargetColumn,
            TransformationType
        FROM Utility.LineageColumnDependency
        WHERE SourceServer = @ServerName
            AND SourceDatabase = @DatabaseName
            AND SourceSchema = @SchemaName
            AND SourceObject = @ObjectName
            AND SourceColumn = @ColumnName
        ORDER BY TargetServer, TargetObject, TargetColumn;
    END
END
GO

-- Find all objects that use a specific table/column
CREATE OR ALTER PROCEDURE Utility.outputLineageColumnUsage
    @ServerName NVARCHAR(128) = NULL,  -- NULL defaults to current server
    @DatabaseName NVARCHAR(128),
    @SchemaName NVARCHAR(128),
    @ObjectName NVARCHAR(128),
    @ColumnName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default to current server if not specified
    IF @ServerName IS NULL
        SET @ServerName = @@SERVERNAME;
    
    -- Objects that reference this column
    SELECT DISTINCT
        SourceServer,
        SourceDatabase,
        SourceSchema,
        SourceObject,
        SourceColumn,
        TransformationType
    FROM Utility.LineageColumnDependency
    WHERE TargetServer = @ServerName
        AND TargetDatabase = @DatabaseName
        AND TargetSchema = @SchemaName
        AND TargetObject = @ObjectName
        AND TargetColumn = @ColumnName
    ORDER BY SourceServer, SourceObject;
END
GO

-- Get dependency tree as hierarchical output
CREATE OR ALTER PROCEDURE Utility.outputLineageDependencyTree
    @ServerName NVARCHAR(128) = NULL,  -- NULL defaults to current server
    @DatabaseName NVARCHAR(128),
    @SchemaName NVARCHAR(128),
    @ObjectName NVARCHAR(128),
    @Direction NVARCHAR(20) = 'Downstream',  -- 'Upstream' or 'Downstream'
    @MaxLevels INT = 5
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default to current server if not specified
    IF @ServerName IS NULL
        SET @ServerName = @@SERVERNAME;
    
    ;WITH DependencyTree AS (
        -- Level 0: The root object
        SELECT 
            @ServerName AS ServerName,
            @DatabaseName AS DatabaseName,
            @SchemaName AS SchemaName,
            @ObjectName AS ObjectName,
            CAST('ROOT' AS NVARCHAR(60)) AS ObjectType,
            0 AS Level,
            CAST(@ServerName + '.' + @DatabaseName + '.' + @SchemaName + '.' + @ObjectName AS NVARCHAR(MAX)) AS TreePath,
            CAST('' AS NVARCHAR(10)) AS Prefix
        
        UNION ALL
        
        -- Recursive: Get dependencies
        SELECT 
            CASE 
                WHEN @Direction = 'Downstream' THEN od.SourceServer
                ELSE od.TargetServer
            END,
            CASE 
                WHEN @Direction = 'Downstream' THEN od.SourceDatabase
                ELSE od.TargetDatabase
            END,
            CASE 
                WHEN @Direction = 'Downstream' THEN od.SourceSchema
                ELSE od.TargetSchema
            END,
            CASE 
                WHEN @Direction = 'Downstream' THEN od.SourceObject
                ELSE od.TargetObject
            END,
            CAST(CASE 
                WHEN @Direction = 'Downstream' THEN od.SourceType
                ELSE od.TargetType
            END AS NVARCHAR(60)),
            dt.Level + 1,
            CAST(dt.TreePath + ' -> ' + 
                CASE 
                    WHEN @Direction = 'Downstream' THEN od.SourceServer + '.' + od.SourceDatabase + '.' + od.SourceSchema + '.' + od.SourceObject
                    ELSE od.TargetServer + '.' + od.TargetDatabase + '.' + od.TargetSchema + '.' + od.TargetObject
                END AS NVARCHAR(MAX)),
            CAST(REPLICATE('  ', dt.Level + 1) + '|--' AS NVARCHAR(10))
        FROM DependencyTree dt
        INNER JOIN Utility.LineageObjectDirectDependency od ON 
            (
                (@Direction = 'Downstream' AND 
                 dt.ServerName = od.TargetServer AND
                 dt.DatabaseName = od.TargetDatabase AND 
                 dt.SchemaName = od.TargetSchema AND 
                 dt.ObjectName = od.TargetObject)
                OR
                (@Direction = 'Upstream' AND 
                 dt.ServerName = od.SourceServer AND
                 dt.DatabaseName = od.SourceDatabase AND 
                 dt.SchemaName = od.SourceSchema AND 
                 dt.ObjectName = od.SourceObject)
            )
        WHERE dt.Level < @MaxLevels
            -- Prevent circular references
            AND dt.TreePath NOT LIKE '%' + 
                CASE 
                    WHEN @Direction = 'Downstream' THEN od.SourceServer + '.' + od.SourceDatabase + '.' + od.SourceSchema + '.' + od.SourceObject
                    ELSE od.TargetServer + '.' + od.TargetDatabase + '.' + od.TargetSchema + '.' + od.TargetObject
                END + '%'
    )
    SELECT 
        Level,
        Prefix + ServerName + '.' + DatabaseName + '.' + SchemaName + '.' + ObjectName AS DependencyTree,
        ObjectType,
        TreePath
    FROM DependencyTree
    ORDER BY TreePath
    OPTION (MAXRECURSION 0);
END
GO
