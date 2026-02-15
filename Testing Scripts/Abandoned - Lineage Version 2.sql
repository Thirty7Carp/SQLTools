/*
===============================================================================
SQL LINEAGE TRACKER - T-SQL (SQL Server)
Identifies dependencies across all databases and all database objects
Supports: Tables, Views, Procedures, Functions, Triggers, Synonyms, and more

Features:
- Captures all objects across all databases
- Tracks direct and indirect dependencies
- Builds complete lineage chains (upstream and downstream)
- Detects circular dependencies
- Identifies orphaned objects
- Cross-database dependency tracking
- Impact analysis
- Column-level lineage tracking

Compatible with: SQL Server 2016+
===============================================================================
*/

-- ============================================================================
-- 1. CREATE CENTRAL REPOSITORY DATABASE (Optional - for storing results)
-- ============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DependencyTracker')
BEGIN
    CREATE DATABASE DependencyTracker;
END
GO

USE DependencyTracker;
GO

-- ============================================================================
-- 2. CREATE TABLES TO STORE DEPENDENCY METADATA
-- ============================================================================
-- Drop existing tables if they exist

IF OBJECT_ID('dbo.DatabaseExclusions', 'U') IS NOT NULL DROP TABLE dbo.DatabaseExclusions;
IF OBJECT_ID('dbo.LineageExclusions', 'U') IS NOT NULL DROP TABLE dbo.LineageExclusions;
IF OBJECT_ID('dbo.ColumnLineage', 'U') IS NOT NULL DROP TABLE dbo.ColumnLineage;
IF OBJECT_ID('dbo.DependencyLineage', 'U') IS NOT NULL DROP TABLE dbo.DependencyLineage;
IF OBJECT_ID('dbo.ObjectDependencies', 'U') IS NOT NULL DROP TABLE dbo.ObjectDependencies;
IF OBJECT_ID('dbo.DatabaseObjects', 'U') IS NOT NULL DROP TABLE dbo.DatabaseObjects;

GO

-- Store all database objects across all databases
CREATE TABLE dbo.DatabaseObjects (
    ObjectID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128) NOT NULL DEFAULT @@SERVERNAME,
    DatabaseName NVARCHAR(128) NOT NULL,
    SchemaName NVARCHAR(128) NOT NULL,
    ObjectName NVARCHAR(128) NOT NULL,
    ObjectType NVARCHAR(60) NOT NULL,
    ObjectTypeName NVARCHAR(60) NOT NULL,
    CreateDate DATETIME,
    ModifyDate DATETIME,
    FullObjectName AS ServerName + '.' + DatabaseName + '.' + SchemaName + '.' + ObjectName,
    CaptureDate DATETIME DEFAULT GETDATE(),
    CONSTRAINT UQ_DatabaseObjects UNIQUE (ServerName, DatabaseName, SchemaName, ObjectName, ObjectType)
);
GO

-- Store direct dependencies between objects
CREATE TABLE dbo.ObjectDependencies (
    DependencyID BIGINT IDENTITY(1,1) PRIMARY KEY,
    SourceServer NVARCHAR(128) NOT NULL DEFAULT @@SERVERNAME,
    SourceDatabase NVARCHAR(128) NOT NULL,
    SourceSchema NVARCHAR(128) NOT NULL,
    SourceObject NVARCHAR(128) NOT NULL,
    SourceType NVARCHAR(60) NOT NULL,
    TargetServer NVARCHAR(128) NOT NULL DEFAULT @@SERVERNAME,
    TargetDatabase NVARCHAR(128) NOT NULL,
    TargetSchema NVARCHAR(128) NOT NULL,
    TargetObject NVARCHAR(128) NOT NULL,
    TargetType NVARCHAR(60) NOT NULL,
    DependencyType NVARCHAR(50) NOT NULL, -- 'Direct', 'Indirect', 'Schema-bound', 'Cross-Server'
    IsSchemabound BIT DEFAULT 0,
    Level INT DEFAULT 1, -- Dependency depth level
    CaptureDate DATETIME DEFAULT GETDATE()
);
GO

-- Store complete lineage paths (upstream and downstream)
CREATE TABLE dbo.DependencyLineage (
    LineageID BIGINT IDENTITY(1,1) PRIMARY KEY,
    RootServer NVARCHAR(128) NOT NULL DEFAULT @@SERVERNAME,
    RootDatabase NVARCHAR(128) NOT NULL,
    RootSchema NVARCHAR(128) NOT NULL,
    RootObject NVARCHAR(128) NOT NULL,
    RootObjectType NVARCHAR(60) NOT NULL,
    DependentServer NVARCHAR(128) NOT NULL DEFAULT @@SERVERNAME,
    DependentDatabase NVARCHAR(128) NOT NULL,
    DependentSchema NVARCHAR(128) NOT NULL,
    DependentObject NVARCHAR(128) NOT NULL,
    DependentObjectType NVARCHAR(60) NOT NULL,
    LineagePath NVARCHAR(MAX), -- Full dependency chain
    LineageLevel INT, -- How many hops from root
    LineageDirection NVARCHAR(20), -- 'Upstream' or 'Downstream'
    CaptureDate DATETIME DEFAULT GETDATE()
);
GO

-- Store column-level dependencies
CREATE TABLE dbo.ColumnLineage (
    ColumnLineageID BIGINT IDENTITY(1,1) PRIMARY KEY,
    SourceServer NVARCHAR(128) NOT NULL DEFAULT @@SERVERNAME,
    SourceDatabase NVARCHAR(128) NOT NULL,
    SourceSchema NVARCHAR(128) NOT NULL,
    SourceObject NVARCHAR(128) NOT NULL,
    SourceColumn NVARCHAR(128) NOT NULL,
    TargetServer NVARCHAR(128) NOT NULL DEFAULT @@SERVERNAME,
    TargetDatabase NVARCHAR(128) NOT NULL,
    TargetSchema NVARCHAR(128) NOT NULL,
    TargetObject NVARCHAR(128) NOT NULL,
    TargetColumn NVARCHAR(128) NOT NULL,
    TransformationType NVARCHAR(100), -- e.g., 'Direct', 'Calculated', 'Aggregated'
    CaptureDate DATETIME DEFAULT GETDATE()
);
GO

-- Store objects to exclude from lineage analysis
CREATE TABLE dbo.LineageExclusions (
    ExclusionID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128) NULL,  -- NULL means all servers
    DatabaseName NVARCHAR(128) NULL,  -- NULL means all databases
    SchemaName NVARCHAR(128) NULL,  -- NULL means all schemas
    ObjectName NVARCHAR(128) NOT NULL,  -- Object name (supports wildcards with LIKE)
    ExclusionReason NVARCHAR(500) NULL,  -- Why this is excluded
    CreatedDate DATETIME DEFAULT GETDATE(),
    CreatedBy NVARCHAR(128) DEFAULT SUSER_SNAME(),
    IsActive BIT DEFAULT 1,  -- Allow disabling without deleting
    CONSTRAINT UQ_LineageExclusions UNIQUE (ServerName, DatabaseName, SchemaName, ObjectName)
);
GO

-- Store databases to exclude from capture
CREATE TABLE dbo.DatabaseExclusions (
    ExclusionID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128) NULL,  -- NULL means all servers
    DatabaseName NVARCHAR(128) NOT NULL,  -- Database name (supports wildcards with LIKE)
    ExclusionReason NVARCHAR(500) NULL,  -- Why this is excluded
    CreatedDate DATETIME DEFAULT GETDATE(),
    CreatedBy NVARCHAR(128) DEFAULT SUSER_SNAME(),
    IsActive BIT DEFAULT 1,  -- Allow disabling without deleting
    CONSTRAINT UQ_DatabaseExclusions UNIQUE (ServerName, DatabaseName)
);
GO

-- Insert default system database exclusions
INSERT INTO dbo.DatabaseExclusions (ServerName, DatabaseName, ExclusionReason)
VALUES 
    (@@SERVERNAME, 'master', 'System database'),
    (@@SERVERNAME, 'tempdb', 'System database'),
    (@@SERVERNAME, 'model', 'System database'),
    (@@SERVERNAME, 'msdb', 'System database');
GO

CREATE INDEX IX_ObjectDependencies_Source ON dbo.ObjectDependencies(SourceServer, SourceDatabase, SourceSchema, SourceObject);
CREATE INDEX IX_ObjectDependencies_Target ON dbo.ObjectDependencies(TargetServer, TargetDatabase, TargetSchema, TargetObject);
CREATE INDEX IX_DependencyLineage_Root ON dbo.DependencyLineage(RootServer, RootDatabase, RootSchema, RootObject);
CREATE INDEX IX_ColumnLineage_Source ON dbo.ColumnLineage(SourceServer, SourceDatabase, SourceSchema, SourceObject, SourceColumn);
CREATE INDEX IX_ColumnLineage_Target ON dbo.ColumnLineage(TargetServer, TargetDatabase, TargetSchema, TargetObject, TargetColumn);
GO

-- ============================================================================
-- 3. STORED PROCEDURE: Capture All Database Objects
-- ============================================================================

CREATE OR ALTER PROCEDURE dbo.usp_CaptureAllDatabaseObjects
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @DatabaseName NVARCHAR(128);
    
    -- Clear existing data
    TRUNCATE TABLE dbo.DatabaseObjects;
    
    -- Cursor to iterate through all accessible databases
    DECLARE db_cursor CURSOR FOR
    SELECT d.name 
    FROM sys.databases d
    WHERE d.state_desc = 'ONLINE' 
        AND HAS_DBACCESS(d.name) = 1
        AND NOT EXISTS (
            SELECT 1 FROM DependencyTracker.dbo.DatabaseExclusions de
            WHERE de.IsActive = 1
                AND (de.ServerName IS NULL OR de.ServerName = @@SERVERNAME)
                AND d.name LIKE de.DatabaseName
        );
    
    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @DatabaseName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            SET @SQL = N'
            INSERT INTO DependencyTracker.dbo.DatabaseObjects 
                (ServerName, DatabaseName, SchemaName, ObjectName, ObjectType, ObjectTypeName, CreateDate, ModifyDate)
            SELECT 
                @@SERVERNAME AS ServerName,
                ''' + @DatabaseName + N''' AS DatabaseName,
                s.name AS SchemaName,
                o.name AS ObjectName,
                o.type AS ObjectType,
                o.type_desc AS ObjectTypeName,
                o.create_date AS CreateDate,
                o.modify_date AS ModifyDate
            FROM [' + @DatabaseName + N'].sys.objects o
            INNER JOIN [' + @DatabaseName + N'].sys.schemas s ON o.schema_id = s.schema_id
            WHERE o.type IN (
                ''U'',  -- User Table
                ''V'',  -- View
                ''P'',  -- Stored Procedure
                ''FN'', -- Scalar Function
                ''IF'', -- Inline Table Function
                ''TF'', -- Table Function
                ''TR'', -- Trigger
                ''SN'', -- Synonym
                ''AF'', -- Aggregate Function
                ''PC'', -- Assembly (CLR) Stored Procedure
                ''FS'', -- Assembly (CLR) Scalar Function
                ''FT'', -- Assembly (CLR) Table Function
                ''SO''  -- Sequence Object
            )
            AND o.is_ms_shipped = 0;';
            
            EXEC sp_executesql @SQL;
        END TRY
        BEGIN CATCH
            PRINT 'Error processing database: ' + @DatabaseName;
            PRINT ERROR_MESSAGE();
        END CATCH
        
        FETCH NEXT FROM db_cursor INTO @DatabaseName;
    END
    
    CLOSE db_cursor;
    DEALLOCATE db_cursor;
    
    SELECT COUNT(*) AS TotalObjectsCaptured FROM dbo.DatabaseObjects;
END
GO

-- ============================================================================
-- 4. STORED PROCEDURE: Capture All Dependencies
-- ============================================================================

CREATE OR ALTER PROCEDURE dbo.usp_CaptureAllDependencies
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @DatabaseName NVARCHAR(128);
    
    -- Clear existing dependencies
    TRUNCATE TABLE dbo.ObjectDependencies;
    
    -- Cursor to iterate through all accessible databases
    DECLARE db_cursor CURSOR FOR
    SELECT d.name 
    FROM sys.databases d
    WHERE d.state_desc = 'ONLINE' 
        AND HAS_DBACCESS(d.name) = 1
        AND NOT EXISTS (
            SELECT 1 FROM DependencyTracker.dbo.DatabaseExclusions de
            WHERE de.IsActive = 1
                AND (de.ServerName IS NULL OR de.ServerName = @@SERVERNAME)
                AND d.name LIKE de.DatabaseName
        );
    
    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @DatabaseName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            SET @SQL = N'
            -- Capture dependencies using sys.sql_expression_dependencies
            -- NOTE: Handles database..object syntax (SQL Server resolves to default schema)
            -- Also captures cross-server dependencies via linked servers
            INSERT INTO DependencyTracker.dbo.ObjectDependencies
                (SourceServer, SourceDatabase, SourceSchema, SourceObject, SourceType,
                 TargetServer, TargetDatabase, TargetSchema, TargetObject, TargetType,
                 DependencyType, IsSchemabound)
            SELECT DISTINCT
                @@SERVERNAME AS SourceServer,
                ''' + @DatabaseName + N''' AS SourceDatabase,
                s.name AS SourceSchema,
                o.name AS SourceObject,
                o.type_desc AS SourceType,
                ISNULL(sed.referenced_server_name, @@SERVERNAME) AS TargetServer,
                ISNULL(sed.referenced_database_name, ''' + @DatabaseName + N''') AS TargetDatabase,
                COALESCE(sed.referenced_schema_name, ts.name, ''dbo'') AS TargetSchema,
                sed.referenced_entity_name AS TargetObject,
                ISNULL(ro.type_desc, ''UNKNOWN'') AS TargetType,
                CASE 
                    WHEN sed.is_schema_bound_reference = 1 THEN ''Schema-bound''
                    WHEN sed.referenced_server_name IS NOT NULL THEN ''Cross-Server''
                    ELSE ''Direct''
                END AS DependencyType,
                sed.is_schema_bound_reference AS IsSchemabound
            FROM [' + @DatabaseName + N'].sys.sql_expression_dependencies sed
            INNER JOIN [' + @DatabaseName + N'].sys.objects o ON sed.referencing_id = o.object_id
            INNER JOIN [' + @DatabaseName + N'].sys.schemas s ON o.schema_id = s.schema_id
            LEFT JOIN [' + @DatabaseName + N'].sys.objects ro ON sed.referenced_id = ro.object_id
            LEFT JOIN [' + @DatabaseName + N'].sys.schemas ts ON ro.schema_id = ts.schema_id
            WHERE o.is_ms_shipped = 0
                AND sed.referenced_entity_name IS NOT NULL;
            
            -- Also capture foreign key dependencies
            INSERT INTO DependencyTracker.dbo.ObjectDependencies
                (SourceServer, SourceDatabase, SourceSchema, SourceObject, SourceType,
                 TargetServer, TargetDatabase, TargetSchema, TargetObject, TargetType,
                 DependencyType, IsSchemabound)
            SELECT DISTINCT
                @@SERVERNAME AS SourceServer,
                ''' + @DatabaseName + N''' AS SourceDatabase,
                s.name AS SourceSchema,
                t.name AS SourceObject,
                ''USER_TABLE'' AS SourceType,
                @@SERVERNAME AS TargetServer,
                ''' + @DatabaseName + N''' AS TargetDatabase,
                rs.name AS TargetSchema,
                rt.name AS TargetObject,
                ''USER_TABLE'' AS TargetType,
                ''Foreign Key'' AS DependencyType,
                0 AS IsSchemabound
            FROM [' + @DatabaseName + N'].sys.foreign_keys fk
            INNER JOIN [' + @DatabaseName + N'].sys.tables t ON fk.parent_object_id = t.object_id
            INNER JOIN [' + @DatabaseName + N'].sys.schemas s ON t.schema_id = s.schema_id
            INNER JOIN [' + @DatabaseName + N'].sys.tables rt ON fk.referenced_object_id = rt.object_id
            INNER JOIN [' + @DatabaseName + N'].sys.schemas rs ON rt.schema_id = rs.schema_id
            WHERE t.is_ms_shipped = 0;';
            
            -- Debug: Print SQL for first database only (to avoid spam)
            IF @DatabaseName = 'AdventureWorks2017'
            BEGIN
                PRINT '=== SQL TO BE EXECUTED FOR AdventureWorks2017 ===';
                PRINT @SQL;
                PRINT '=== END SQL ===';
            END
            
            EXEC sp_executesql @SQL;
        END TRY
        BEGIN CATCH
            PRINT 'Error processing dependencies for database: ' + @DatabaseName;
            PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(10));
            PRINT 'Error Message: ' + ERROR_MESSAGE();
            PRINT 'Error Line: ' + CAST(ERROR_LINE() AS VARCHAR(10));
        END CATCH
        
        -- Debug output: show progress
        DECLARE @RowCount INT;
        SELECT @RowCount = COUNT(*) FROM dbo.ObjectDependencies WHERE SourceDatabase = @DatabaseName;
        PRINT 'Processed database: ' + @DatabaseName + ' - Dependencies captured: ' + CAST(@RowCount AS VARCHAR(10));
        
        FETCH NEXT FROM db_cursor INTO @DatabaseName;
    END
    
    CLOSE db_cursor;
    DEALLOCATE db_cursor;
    
    SELECT COUNT(*) AS TotalDependenciesCaptured FROM dbo.ObjectDependencies;
END
GO

-- ============================================================================
-- 5. STORED PROCEDURE: Build Complete Lineage (Recursive)
-- ============================================================================

CREATE OR ALTER PROCEDURE dbo.usp_BuildCompleteLineage
    @MaxLevels INT = 10  -- Maximum recursion depth
AS
BEGIN
    SET NOCOUNT ON;
    
    TRUNCATE TABLE dbo.DependencyLineage;
    
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
        FROM dbo.ObjectDependencies od
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.LineageExclusions le
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
        INNER JOIN dbo.ObjectDependencies od 
            ON rd.DependentServer = od.SourceServer
            AND rd.DependentDatabase = od.SourceDatabase
            AND rd.DependentSchema = od.SourceSchema
            AND rd.DependentObject = od.SourceObject
        WHERE rd.LineageLevel < @MaxLevels
            -- Prevent circular references
            AND rd.LineagePath NOT LIKE '%' + od.TargetServer + '.' + od.TargetDatabase + '.' + od.TargetSchema + '.' + od.TargetObject + '%'
            -- Exclude objects in exclusion list
            AND NOT EXISTS (
                SELECT 1 FROM dbo.LineageExclusions le
                WHERE le.IsActive = 1
                    AND (le.ServerName IS NULL OR le.ServerName = od.TargetServer)
                    AND (le.DatabaseName IS NULL OR le.DatabaseName = od.TargetDatabase)
                    AND (le.SchemaName IS NULL OR le.SchemaName = od.TargetSchema)
                    AND od.TargetObject LIKE le.ObjectName
            )
    )
    INSERT INTO dbo.DependencyLineage 
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
        FROM dbo.ObjectDependencies od
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.LineageExclusions le
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
        INNER JOIN dbo.ObjectDependencies od 
            ON ru.DependentServer = od.TargetServer
            AND ru.DependentDatabase = od.TargetDatabase
            AND ru.DependentSchema = od.TargetSchema
            AND ru.DependentObject = od.TargetObject
        WHERE ru.LineageLevel < @MaxLevels
            AND ru.LineagePath NOT LIKE '%' + od.SourceServer + '.' + od.SourceDatabase + '.' + od.SourceSchema + '.' + od.SourceObject + '%'
            -- Exclude objects in exclusion list
            AND NOT EXISTS (
                SELECT 1 FROM dbo.LineageExclusions le
                WHERE le.IsActive = 1
                    AND (le.ServerName IS NULL OR le.ServerName = od.SourceServer)
                    AND (le.DatabaseName IS NULL OR le.DatabaseName = od.SourceDatabase)
                    AND (le.SchemaName IS NULL OR le.SchemaName = od.SourceSchema)
                    AND od.SourceObject LIKE le.ObjectName
            )
    )
    INSERT INTO dbo.DependencyLineage 
        (RootServer, RootDatabase, RootSchema, RootObject, RootObjectType,
         DependentServer, DependentDatabase, DependentSchema, DependentObject, DependentObjectType,
         LineagePath, LineageLevel, LineageDirection)
    SELECT DISTINCT
        RootServer, RootDatabase, RootSchema, RootObject, RootObjectType,
        DependentServer, DependentDatabase, DependentSchema, DependentObject, DependentObjectType,
        LineagePath, LineageLevel, 'Upstream'
    FROM RecursiveUpstream
    OPTION (MAXRECURSION 0);
    
    SELECT COUNT(*) AS TotalLineagePathsCaptured FROM dbo.DependencyLineage;
END
GO

-- ============================================================================
-- 6. STORED PROCEDURE: Capture Column-Level Lineage
-- ============================================================================

CREATE OR ALTER PROCEDURE dbo.usp_CaptureColumnLineage
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @DatabaseName NVARCHAR(128);
    
    -- Clear existing column lineage
    TRUNCATE TABLE dbo.ColumnLineage;
    
    -- Cursor to iterate through all accessible databases
    DECLARE db_cursor CURSOR FOR
    SELECT d.name 
    FROM sys.databases d
    WHERE d.state_desc = 'ONLINE' 
        AND HAS_DBACCESS(d.name) = 1
        AND NOT EXISTS (
            SELECT 1 FROM DependencyTracker.dbo.DatabaseExclusions de
            WHERE de.IsActive = 1
                AND (de.ServerName IS NULL OR de.ServerName = @@SERVERNAME)
                AND d.name LIKE de.DatabaseName
        );
    
    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @DatabaseName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            SET @SQL = N'
            -- Capture column-level dependencies from views
            INSERT INTO DependencyTracker.dbo.ColumnLineage
                (SourceServer, SourceDatabase, SourceSchema, SourceObject, SourceColumn,
                 TargetServer, TargetDatabase, TargetSchema, TargetObject, TargetColumn,
                 TransformationType)
            SELECT DISTINCT
                @@SERVERNAME AS SourceServer,
                ''' + @DatabaseName + N''' AS SourceDatabase,
                s.name AS SourceSchema,
                v.name AS SourceObject,
                vc.name AS SourceColumn,
                ISNULL(sed.referenced_server_name, @@SERVERNAME) AS TargetServer,
                COALESCE(sed.referenced_database_name, ''' + @DatabaseName + N''') AS TargetDatabase,
                ISNULL(sed.referenced_schema_name, ''dbo'') AS TargetSchema,
                sed.referenced_entity_name AS TargetObject,
                COALESCE(sed.referenced_minor_name, vc.name) AS TargetColumn,
                ''Direct'' AS TransformationType
            FROM [' + @DatabaseName + N'].sys.views v
            INNER JOIN [' + @DatabaseName + N'].sys.schemas s ON v.schema_id = s.schema_id
            INNER JOIN [' + @DatabaseName + N'].sys.columns vc ON v.object_id = vc.object_id
            CROSS APPLY [' + @DatabaseName + N'].sys.dm_sql_referenced_entities(
                s.name + ''.'' + v.name, ''OBJECT''
            ) sed
            WHERE sed.referenced_minor_name IS NOT NULL
                AND v.is_ms_shipped = 0;
            
            -- Capture column-level dependencies from stored procedures and functions
            INSERT INTO DependencyTracker.dbo.ColumnLineage
                (SourceServer, SourceDatabase, SourceSchema, SourceObject, SourceColumn,
                 TargetServer, TargetDatabase, TargetSchema, TargetObject, TargetColumn,
                 TransformationType)
            SELECT DISTINCT
                @@SERVERNAME AS SourceServer,
                ''' + @DatabaseName + N''' AS SourceDatabase,
                s.name AS SourceSchema,
                o.name AS SourceObject,
                sed.referenced_minor_name AS SourceColumn,
                ISNULL(sed.referenced_server_name, @@SERVERNAME) AS TargetServer,
                COALESCE(sed.referenced_database_name, ''' + @DatabaseName + N''') AS TargetDatabase,
                ISNULL(sed.referenced_schema_name, ''dbo'') AS TargetSchema,
                sed.referenced_entity_name AS TargetObject,
                sed.referenced_minor_name AS TargetColumn,
                ''Procedure/Function Reference'' AS TransformationType
            FROM [' + @DatabaseName + N'].sys.objects o
            INNER JOIN [' + @DatabaseName + N'].sys.schemas s ON o.schema_id = s.schema_id
            CROSS APPLY [' + @DatabaseName + N'].sys.dm_sql_referenced_entities(
                s.name + ''.'' + o.name, ''OBJECT''
            ) sed
            WHERE o.type IN (''P'', ''FN'', ''IF'', ''TF'')
                AND sed.referenced_minor_name IS NOT NULL
                AND o.is_ms_shipped = 0;';
            
            EXEC sp_executesql @SQL;
        END TRY
        BEGIN CATCH
            PRINT 'Error processing column lineage for database: ' + @DatabaseName;
            PRINT ERROR_MESSAGE();
        END CATCH
        
        FETCH NEXT FROM db_cursor INTO @DatabaseName;
    END
    
    CLOSE db_cursor;
    DEALLOCATE db_cursor;
    
    SELECT COUNT(*) AS TotalColumnLineageCaptured FROM dbo.ColumnLineage;
END
GO

-- ============================================================================
-- 7. VIEWS FOR EASY QUERYING
-- ============================================================================

-- View: All objects with their dependency counts
CREATE OR ALTER VIEW vw_ObjectDependencySummary
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
FROM dbo.DatabaseObjects o
LEFT JOIN (
    SELECT SourceServer, SourceDatabase, SourceSchema, SourceObject, COUNT(*) AS DependsOnCount
    FROM dbo.ObjectDependencies
    GROUP BY SourceServer, SourceDatabase, SourceSchema, SourceObject
) deps_out ON o.ServerName = deps_out.SourceServer 
    AND o.DatabaseName = deps_out.SourceDatabase 
    AND o.SchemaName = deps_out.SourceSchema 
    AND o.ObjectName = deps_out.SourceObject
LEFT JOIN (
    SELECT TargetServer, TargetDatabase, TargetSchema, TargetObject, COUNT(*) AS DependedByCount
    FROM dbo.ObjectDependencies
    GROUP BY TargetServer, TargetDatabase, TargetSchema, TargetObject
) deps_in ON o.ServerName = deps_in.TargetServer 
    AND o.DatabaseName = deps_in.TargetDatabase 
    AND o.SchemaName = deps_in.TargetSchema 
    AND o.ObjectName = deps_in.TargetObject;
GO

-- View: Direct dependencies with full details
CREATE OR ALTER VIEW vw_DirectDependencies
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
FROM dbo.ObjectDependencies od;
GO

-- View: Circular dependencies detection
CREATE OR ALTER VIEW vw_CircularDependencies
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
FROM dbo.ObjectDependencies d1
INNER JOIN dbo.ObjectDependencies d2 
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
CREATE OR ALTER VIEW vw_OrphanedObjects
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
FROM dbo.DatabaseObjects o
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.ObjectDependencies od
    WHERE (od.SourceServer = o.ServerName AND od.SourceDatabase = o.DatabaseName AND od.SourceSchema = o.SchemaName AND od.SourceObject = o.ObjectName)
       OR (od.TargetServer = o.ServerName AND od.TargetDatabase = o.DatabaseName AND od.TargetSchema = o.SchemaName AND od.TargetObject = o.ObjectName)
);
GO

-- ============================================================================
-- 8. UTILITY PROCEDURES FOR SPECIFIC QUERIES
-- ============================================================================

-- Get all dependencies for a specific object
CREATE OR ALTER PROCEDURE dbo.usp_GetObjectLineage
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
        FROM dbo.DependencyLineage
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
        FROM dbo.DependencyLineage
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
CREATE OR ALTER PROCEDURE dbo.usp_GetImpactAnalysis
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
    FROM dbo.DependencyLineage
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
    FROM dbo.DependencyLineage
    WHERE RootServer = @ServerName
        AND RootDatabase = @DatabaseName
        AND RootSchema = @SchemaName
        AND RootObject = @ObjectName
        AND LineageDirection = 'Downstream';
END
GO

-- Get all cross-database and cross-server dependencies
CREATE OR ALTER PROCEDURE dbo.usp_GetCrossDatabaseDependencies
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
    FROM dbo.ObjectDependencies
    WHERE SourceServer <> TargetServer 
       OR SourceDatabase <> TargetDatabase
    ORDER BY Scope, SourceServer, SourceDatabase, TargetServer, TargetDatabase, SourceSchema, SourceObject;
END
GO

-- ============================================================================
-- 9. EXCLUSION MANAGEMENT PROCEDURES
-- ============================================================================

-- Add a database exclusion
CREATE OR ALTER PROCEDURE dbo.usp_AddDatabaseExclusion
    @ServerName NVARCHAR(128) = NULL,
    @DatabaseName NVARCHAR(128),
    @ExclusionReason NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO dbo.DatabaseExclusions (ServerName, DatabaseName, ExclusionReason)
    VALUES (@ServerName, @DatabaseName, @ExclusionReason);
    
    PRINT 'Database exclusion added: ' + ISNULL(@ServerName + '.', '') + @DatabaseName;
END
GO

-- Remove a database exclusion
CREATE OR ALTER PROCEDURE dbo.usp_RemoveDatabaseExclusion
    @ExclusionID BIGINT = NULL,
    @ServerName NVARCHAR(128) = NULL,
    @DatabaseName NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @ExclusionID IS NOT NULL
    BEGIN
        DELETE FROM dbo.DatabaseExclusions WHERE ExclusionID = @ExclusionID;
        PRINT 'Database exclusion removed (ID: ' + CAST(@ExclusionID AS VARCHAR(10)) + ')';
    END
    ELSE
    BEGIN
        DELETE FROM dbo.DatabaseExclusions
        WHERE (ServerName = @ServerName OR (ServerName IS NULL AND @ServerName IS NULL))
            AND DatabaseName = @DatabaseName;
        
        PRINT 'Database exclusion removed: ' + ISNULL(@ServerName + '.', '') + @DatabaseName;
    END
END
GO

-- View all database exclusions
CREATE OR ALTER PROCEDURE dbo.usp_ViewDatabaseExclusions
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
    FROM dbo.DatabaseExclusions
    ORDER BY ServerName, DatabaseName;
END
GO

-- Add default system database exclusions
CREATE OR ALTER PROCEDURE dbo.usp_AddDefaultDatabaseExclusions
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Add standard system databases
    INSERT INTO dbo.DatabaseExclusions (DatabaseName, ExclusionReason)
    SELECT 'master', 'System database'
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DatabaseExclusions WHERE DatabaseName = 'master');
    
    INSERT INTO dbo.DatabaseExclusions (DatabaseName, ExclusionReason)
    SELECT 'tempdb', 'System database'
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DatabaseExclusions WHERE DatabaseName = 'tempdb');
    
    INSERT INTO dbo.DatabaseExclusions (DatabaseName, ExclusionReason)
    SELECT 'model', 'System database'
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DatabaseExclusions WHERE DatabaseName = 'model');
    
    INSERT INTO dbo.DatabaseExclusions (DatabaseName, ExclusionReason)
    SELECT 'msdb', 'System database'
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DatabaseExclusions WHERE DatabaseName = 'msdb');
    
    PRINT 'Default database exclusions added (master, tempdb, model, msdb)';
END
GO

-- Add an object lineage exclusion
CREATE OR ALTER PROCEDURE dbo.usp_AddLineageExclusion
    @ServerName NVARCHAR(128) = NULL,
    @DatabaseName NVARCHAR(128) = NULL,
    @SchemaName NVARCHAR(128) = NULL,
    @ObjectName NVARCHAR(128),
    @ExclusionReason NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO dbo.LineageExclusions (ServerName, DatabaseName, SchemaName, ObjectName, ExclusionReason)
    VALUES (@ServerName, @DatabaseName, @SchemaName, @ObjectName, @ExclusionReason);
    
    PRINT 'Exclusion added for: ' + ISNULL(@ServerName + '.', '') + ISNULL(@DatabaseName + '.', '') + 
          ISNULL(@SchemaName + '.', '') + @ObjectName;
END
GO

-- Remove an object lineage exclusion
CREATE OR ALTER PROCEDURE dbo.usp_RemoveLineageExclusion
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
        DELETE FROM dbo.LineageExclusions WHERE ExclusionID = @ExclusionID;
        PRINT 'Exclusion removed (ID: ' + CAST(@ExclusionID AS VARCHAR(10)) + ')';
    END
    ELSE
    BEGIN
        DELETE FROM dbo.LineageExclusions
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
CREATE OR ALTER PROCEDURE dbo.usp_ViewLineageExclusions
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
    FROM dbo.LineageExclusions
    ORDER BY ServerName, DatabaseName, SchemaName, ObjectName;
END
GO

-- ============================================================================
-- 10. MASTER PROCEDURE: Run Complete Lineage Analysis
-- ============================================================================

CREATE OR ALTER PROCEDURE dbo.usp_RunCompleteLineageAnalysis
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
    EXEC dbo.usp_CaptureAllDatabaseObjects;
    SELECT @ObjectCount = COUNT(*) FROM dbo.DatabaseObjects;
    PRINT 'Objects captured: ' + CAST(@ObjectCount AS VARCHAR(10));
    PRINT '';
    
    -- Step 2: Capture all dependencies
    PRINT 'Step 2: Capturing all dependencies...';
    EXEC dbo.usp_CaptureAllDependencies;
    SELECT @DependencyCount = COUNT(*) FROM dbo.ObjectDependencies;
    PRINT 'Dependencies captured: ' + CAST(@DependencyCount AS VARCHAR(10));
    PRINT '';
    
    -- Step 3: Build complete lineage
    PRINT 'Step 3: Building complete lineage...';
    EXEC dbo.usp_BuildCompleteLineage @MaxLevels = 10;
    SELECT @LineageCount = COUNT(*) FROM dbo.DependencyLineage;
    PRINT 'Lineage paths built: ' + CAST(@LineageCount AS VARCHAR(10));
    PRINT '';
    
    -- Step 4: Capture column-level lineage
    PRINT 'Step 4: Capturing column-level lineage...';
    EXEC dbo.usp_CaptureColumnLineage;
    DECLARE @ColumnLineageCount INT;
    SELECT @ColumnLineageCount = COUNT(*) FROM dbo.ColumnLineage;
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
    FROM dbo.DatabaseObjects
    GROUP BY ObjectTypeName
    ORDER BY COUNT(*) DESC;
    
    -- Database breakdown
    PRINT '';
    PRINT '=== DATABASE BREAKDOWN ===';
    SELECT DatabaseName, COUNT(*) AS ObjectCount
    FROM dbo.DatabaseObjects
    GROUP BY DatabaseName
    ORDER BY COUNT(*) DESC;
END
GO

-- ============================================================================
-- 10. ADDITIONAL UTILITY PROCEDURES
-- ============================================================================

-- Get column lineage for a specific column
CREATE OR ALTER PROCEDURE dbo.usp_GetColumnLineage
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
        FROM dbo.ColumnLineage
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
        FROM dbo.ColumnLineage
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
CREATE OR ALTER PROCEDURE dbo.usp_FindColumnUsage
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
    FROM dbo.ColumnLineage
    WHERE TargetServer = @ServerName
        AND TargetDatabase = @DatabaseName
        AND TargetSchema = @SchemaName
        AND TargetObject = @ObjectName
        AND TargetColumn = @ColumnName
    ORDER BY SourceServer, SourceObject;
END
GO

-- Get dependency tree as hierarchical output
CREATE OR ALTER PROCEDURE dbo.usp_GetDependencyTree
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
        INNER JOIN dbo.ObjectDependencies od ON 
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

-- ============================================================================
-- 11. USAGE EXAMPLES
-- ============================================================================

/*
-- Run complete analysis
EXEC dbo.usp_RunCompleteLineageAnalysis;

-- ============================================================================
-- DATABASE EXCLUSION EXAMPLES
-- ============================================================================

-- Add default system database exclusions (master, tempdb, model, msdb)
EXEC dbo.usp_AddDefaultDatabaseExclusions;

-- Exclude a specific database
EXEC dbo.usp_AddDatabaseExclusion
    @DatabaseName = 'OldDatabase',
    @ExclusionReason = 'Deprecated database';

-- Exclude all databases matching a pattern (e.g., all test databases)
EXEC dbo.usp_AddDatabaseExclusion
    @DatabaseName = 'Test%',
    @ExclusionReason = 'All test databases';

-- Exclude a database on a specific server
EXEC dbo.usp_AddDatabaseExclusion
    @ServerName = 'DEV_SERVER',
    @DatabaseName = 'Sandbox',
    @ExclusionReason = 'Development sandbox';

-- View all database exclusions
EXEC dbo.usp_ViewDatabaseExclusions;

-- Remove a database exclusion by ID
EXEC dbo.usp_RemoveDatabaseExclusion @ExclusionID = 1;

-- Remove a database exclusion by name
EXEC dbo.usp_RemoveDatabaseExclusion
    @DatabaseName = 'OldDatabase';

-- ============================================================================
-- LINEAGE EXCLUSION EXAMPLES
-- ============================================================================

-- Exclude a specific error log table in a specific database
EXEC dbo.usp_AddLineageExclusion
    @DatabaseName = 'MyDatabase',
    @SchemaName = 'dbo',
    @ObjectName = 'ErrorLog',
    @ExclusionReason = 'Error log table - too many dependencies';

-- Exclude all objects with 'Log' in the name across all databases
EXEC dbo.usp_AddLineageExclusion
    @ObjectName = '%Log%',
    @ExclusionReason = 'All logging tables';

-- Exclude audit tables in a specific schema
EXEC dbo.usp_AddLineageExclusion
    @SchemaName = 'Audit',
    @ObjectName = '%',
    @ExclusionReason = 'All audit schema objects';

-- View all exclusions
EXEC dbo.usp_ViewLineageExclusions;

-- Remove an exclusion by ID
EXEC dbo.usp_RemoveLineageExclusion @ExclusionID = 1;

-- Remove an exclusion by name
EXEC dbo.usp_RemoveLineageExclusion
    @DatabaseName = 'MyDatabase',
    @SchemaName = 'dbo',
    @ObjectName = 'ErrorLog';

-- After adding/removing exclusions, rebuild lineage
EXEC dbo.usp_BuildCompleteLineage @MaxLevels = 10;

-- ============================================================================
-- OTHER USAGE EXAMPLES
-- ============================================================================

-- Get lineage for a specific object
EXEC dbo.usp_GetObjectLineage 
    @DatabaseName = 'YourDatabase',
    @SchemaName = 'dbo',
    @ObjectName = 'YourTable',
    @Direction = 'Both';

-- Get impact analysis
EXEC dbo.usp_GetImpactAnalysis
    @DatabaseName = 'YourDatabase',
    @SchemaName = 'dbo',
    @ObjectName = 'YourTable';

-- Get cross-database dependencies
EXEC dbo.usp_GetCrossDatabaseDependencies;

-- Get column lineage for an object
EXEC dbo.usp_GetColumnLineage
    @DatabaseName = 'YourDatabase',
    @SchemaName = 'dbo',
    @ObjectName = 'YourView',
    @ColumnName = NULL; -- NULL for all columns

-- Find where a specific column is used
EXEC dbo.usp_FindColumnUsage
    @DatabaseName = 'YourDatabase',
    @SchemaName = 'dbo',
    @ObjectName = 'YourTable',
    @ColumnName = 'CustomerID';

-- Get dependency tree visualization
EXEC dbo.usp_GetDependencyTree
    @DatabaseName = 'YourDatabase',
    @SchemaName = 'dbo',
    @ObjectName = 'YourTable',
    @Direction = 'Downstream',
    @MaxLevels = 5;

-- View all objects with dependency counts
SELECT * FROM vw_ObjectDependencySummary
ORDER BY TotalDependencies DESC;

-- View circular dependencies
SELECT * FROM vw_CircularDependencies;

-- View orphaned objects
SELECT * FROM vw_OrphanedObjects;

-- Get most depended-upon objects
SELECT TOP 20 * FROM vw_ObjectDependencySummary
ORDER BY DependedByCount DESC;

-- Get objects with most dependencies
SELECT TOP 20 * FROM vw_ObjectDependencySummary
ORDER BY DependsOnCount DESC;

-- Find all dependencies for tables in a specific database
SELECT * FROM vw_DirectDependencies
WHERE SourceDatabase = 'YourDatabase'
    AND SourceType = 'USER_TABLE'
ORDER BY SourceObject;

-- Find all views that depend on a specific table
SELECT DISTINCT
    SourceDatabase,
    SourceSchema,
    SourceObject,
    SourceType
FROM dbo.ObjectDependencies
WHERE TargetDatabase = 'YourDatabase'
    AND TargetSchema = 'dbo'
    AND TargetObject = 'YourTable'
    AND SourceType = 'VIEW';

-- Get full lineage path for a specific object (all levels)
SELECT 
    LineageLevel,
    LineagePath
FROM dbo.DependencyLineage
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
FROM dbo.DatabaseObjects
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.ObjectDependencies
    WHERE SourceDatabase = DatabaseObjects.DatabaseName
        AND SourceSchema = DatabaseObjects.SchemaName
        AND SourceObject = DatabaseObjects.ObjectName
)
AND NOT EXISTS (
    SELECT 1 FROM dbo.ObjectDependencies
    WHERE TargetDatabase = DatabaseObjects.DatabaseName
        AND TargetSchema = DatabaseObjects.SchemaName
        AND TargetObject = DatabaseObjects.ObjectName
);

-- Column-level impact analysis
SELECT 
    cl.SourceDatabase + '.' + cl.SourceSchema + '.' + cl.SourceObject AS AffectedObject,
    cl.SourceColumn AS AffectedColumn,
    cl.TransformationType
FROM dbo.ColumnLineage cl
WHERE cl.TargetDatabase = 'YourDatabase'
    AND cl.TargetSchema = 'dbo'
    AND cl.TargetObject = 'YourTable'
    AND cl.TargetColumn = 'YourColumn'
ORDER BY cl.SourceObject, cl.SourceColumn;
*/