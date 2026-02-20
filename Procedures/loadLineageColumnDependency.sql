
CREATE OR ALTER PROCEDURE Utility.loadLineageColumnDependency
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @CursorSQL NVARCHAR(MAX);
    DECLARE @DatabaseName NVARCHAR(128);
    DECLARE @UtilitySchemaDatabase sysname = 'SQLTools';
    
    -- Clear existing column lineage
    TRUNCATE TABLE Utility.LineageColumnDependency;
    

    SET @CursorSQL = N'
        DECLARE db_cursor CURSOR FOR
        SELECT d.name 
        FROM sys.databases d
        WHERE d.state_desc = ''ONLINE'' 
            AND HAS_DBACCESS(d.name) = 1
            AND NOT EXISTS (
                SELECT 1 
                FROM ' + QUOTENAME(@UtilitySchemaDatabase) + '.Utility.LineageDatabaseExclusions de
                WHERE de.IsActive = 1
                    AND (de.ServerName IS NULL OR de.ServerName = @@SERVERNAME)
                    AND d.name LIKE de.DatabaseName
            );
    ';

    EXEC sys.sp_executesql @CursorSQL;

    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @DatabaseName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            --------------------------------------------------------------------
            -- Build dynamic SQL for column-level lineage extraction
            --------------------------------------------------------------------
            SET @SQL = N'
            -- Capture column-level dependencies from views
            INSERT INTO ' + QUOTENAME(@UtilitySchemaDatabase) + '.Utility.LineageColumnDependency
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
            INSERT INTO ' + QUOTENAME(@UtilitySchemaDatabase) + '.Utility.LineageColumnDependency
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
                AND o.is_ms_shipped = 0;
            ';

            EXEC sys.sp_executesql @SQL;
        END TRY
        BEGIN CATCH
            PRINT 'Error processing column lineage for database: ' + @DatabaseName;
            PRINT ERROR_MESSAGE();
        END CATCH
        
        FETCH NEXT FROM db_cursor INTO @DatabaseName;
    END
    
    CLOSE db_cursor;
    DEALLOCATE db_cursor;
    
    SELECT COUNT(*) AS TotalColumnLineageCaptured 
    FROM Utility.LineageColumnDependency;
END
GO