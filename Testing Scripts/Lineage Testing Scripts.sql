
-- ============================================================================
-- 11. USAGE EXAMPLES
-- ============================================================================

-- Run complete analysis
EXEC Utility.batchLineageAnalysis;

-- ============================================================================
-- DATABASE EXCLUSION EXAMPLES
-- ============================================================================

-- Add default system database exclusions (master, tempdb, model, msdb)
EXEC Utility.alterLineageDatabaseExclusionsAddDefaults;

-- Exclude a specific database
EXEC Utility.alterLineageDatabaseExclusionsAdd
    @DatabaseName = 'OldDatabase',
    @ExclusionReason = 'Deprecated database';

-- Exclude all databases matching a pattern (e.g., all test databases)
EXEC Utility.alterLineageDatabaseExclusionsAdd
    @DatabaseName = 'Test%',
    @ExclusionReason = 'All test databases';

-- Exclude a database on a specific server
EXEC Utility.alterLineageDatabaseExclusionsAdd
    @ServerName = 'DEV_SERVER',
    @DatabaseName = 'Sandbox',
    @ExclusionReason = 'Development sandbox';

-- View all database exclusions
EXEC Utility.outputLineageDatabaseExclusions;

-- Remove a database exclusion by ID
EXEC Utility.alterLineageDatabaseExclusionsRemove @ExclusionID = 1;

-- Remove a database exclusion by name
EXEC Utility.alterLineageDatabaseExclusionsRemove
    @DatabaseName = 'OldDatabase';

-- ============================================================================
-- LINEAGE EXCLUSION EXAMPLES
-- ============================================================================

-- Exclude a specific error log table in a specific database
EXEC Utility.alterLineageObjectExclusionsAdd
    @DatabaseName = 'MyDatabase',
    @SchemaName = 'dbo',
    @ObjectName = 'ErrorLog',
    @ExclusionReason = 'Error log table - too many dependencies';

-- Exclude all objects with 'Log' in the name across all databases
EXEC Utility.alterLineageObjectExclusionsAdd
    @ObjectName = '%Log%',
    @ExclusionReason = 'All logging tables';

-- Exclude audit tables in a specific schema
EXEC Utility.alterLineageObjectExclusionsAdd
    @SchemaName = 'Audit',
    @ObjectName = '%',
    @ExclusionReason = 'All audit schema objects';

-- View all exclusions
EXEC Utility.outputLineageObjectExclusions;

-- Remove an exclusion by ID
EXEC Utility.alterLineageObjectExclusionsRemove @ExclusionID = 1;

-- Remove an exclusion by name
EXEC Utility.alterLineageObjectExclusionsRemove
    @DatabaseName = 'MyDatabase',
    @SchemaName = 'dbo',
    @ObjectName = 'ErrorLog';

-- After adding/removing exclusions, rebuild lineage
EXEC Utility.updateLineageObjectExtendedDependency @MaxLevels = 10;

-- ============================================================================
-- OTHER USAGE EXAMPLES
-- ============================================================================

-- Get lineage for a specific object
EXEC Utility.outputLineageObjectDependency 
    @DatabaseName = 'YourDatabase',
    @SchemaName = 'dbo',
    @ObjectName = 'YourTable',
    @Direction = 'Both';

-- Get impact analysis
EXEC Utility.outputLineageImpactAnalysis
    @DatabaseName = 'YourDatabase',
    @SchemaName = 'dbo',
    @ObjectName = 'YourTable';

-- Get cross-database dependencies
EXEC Utility.outputLineageCrossDatabaseDependency;

-- Get column lineage for an object
EXEC Utility.outputLineageColumnDependency
    @DatabaseName = 'YourDatabase',
    @SchemaName = 'dbo',
    @ObjectName = 'YourView',
    @ColumnName = NULL; -- NULL for all columns

-- Find where a specific column is used
EXEC Utility.outputLineageColumnUsage
    @DatabaseName = 'YourDatabase',
    @SchemaName = 'dbo',
    @ObjectName = 'YourTable',
    @ColumnName = 'CustomerID';

-- Get dependency tree visualization
EXEC Utility.outputLineageDependencyTree
    @DatabaseName = 'YourDatabase',
    @SchemaName = 'dbo',
    @ObjectName = 'YourTable',
    @Direction = 'Downstream',
    @MaxLevels = 5;

-- View all objects with dependency counts
SELECT * FROM Utility.vwLineageObjectSummary
ORDER BY TotalDependencies DESC;

-- View circular dependencies
SELECT * FROM Utility.vwLineageObjectCircularDependency;

-- View orphaned objects
SELECT * FROM Utility.vwLineageObjectOrphaned;

-- Get most depended-upon objects
SELECT TOP 20 * FROM Utility.vwLineageObjectSummary
ORDER BY DependedByCount DESC;

-- Get objects with most dependencies
SELECT TOP 20 * FROM Utility.vwLineageObjectSummary
ORDER BY DependsOnCount DESC;

-- Find all dependencies for tables in a specific database
SELECT * FROM Utility.vwLineageObjectDirectDependency
WHERE SourceDatabase = 'YourDatabase'
    AND SourceType = 'USER_TABLE'
ORDER BY SourceObject;

-- Find all views that depend on a specific table
SELECT DISTINCT
    SourceDatabase,
    SourceSchema,
    SourceObject,
    SourceType
FROM Utility.LineageObjectDirectDependency
WHERE TargetDatabase = 'YourDatabase'
    AND TargetSchema = 'dbo'
    AND TargetObject = 'YourTable'
    AND SourceType = 'VIEW';

-- Get full lineage path for a specific object (all levels)
SELECT 
    LineageLevel,
    LineagePath
FROM Utility.LineageObjectExtendedDependency
WHERE RootDatabase = 'YourDatabase'
    AND RootSchema = 'dbo'
    AND RootObject = 'YourTable'
    AND LineageDirection = 'Downstream'
ORDER BY LineageLevel, LineagePath;

-- Find objects with no dependencies (candidates for removal)
SELECT 
    DatabaseName,
    SchemaName,
    ObjectName,
    ObjectTypeName
FROM Utility.LineageObjectList
WHERE NOT EXISTS (
    SELECT 1 FROM Utility.LineageObjectDirectDependency
    WHERE SourceDatabase = LineageObjectList.DatabaseName
        AND SourceSchema = LineageObjectList.SchemaName
        AND SourceObject = LineageObjectList.ObjectName
)
AND NOT EXISTS (
    SELECT 1 FROM Utility.LineageObjectDirectDependency
    WHERE TargetDatabase = LineageObjectList.DatabaseName
        AND TargetSchema = LineageObjectList.SchemaName
        AND TargetObject = LineageObjectList.ObjectName
);

-- Column-level impact analysis
SELECT 
    cl.SourceDatabase + '.' + cl.SourceSchema + '.' + cl.SourceObject AS AffectedObject,
    cl.SourceColumn AS AffectedColumn,
    cl.TransformationType
FROM Utility.LineageColumnDependency cl
WHERE cl.TargetDatabase = 'YourDatabase'
    AND cl.TargetSchema = 'dbo'
    AND cl.TargetObject = 'YourTable'
    AND cl.TargetColumn = 'YourColumn'
ORDER BY cl.SourceObject, cl.SourceColumn;