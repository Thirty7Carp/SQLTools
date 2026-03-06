CREATE PROCEDURE Utility.loadLineageObjectDirectDependency
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @CursorSQL NVARCHAR(MAX);
    DECLARE @DatabaseName NVARCHAR(128);
    DECLARE @UtilitySchemaDatabase sysname = 'SQLTools';

    -- Clear existing dependencies


    TRUNCATE TABLE Utility.LineageObjectDirectDependency;

    SET @CursorSQL = N'
        DECLARE db_cursor CURSOR FOR
        SELECT d.name 
        FROM sys.databases d
        WHERE d.state_desc = ''ONLINE'' 
            AND HAS_DBACCESS(d.name) = 1
            AND NOT EXISTS (
                SELECT 1 
                FROM ' + CAST(QUOTENAME(@UtilitySchemaDatabase) AS NVARCHAR(MAX)) + '.Utility.LineageDatabaseExclusions de
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
            -- Build dynamic SQL for dependency extraction
            --------------------------------------------------------------------
            SET @SQL = N'
            INSERT INTO ' + CAST(QUOTENAME(@UtilitySchemaDatabase) AS NVARCHAR(MAX)) + '.Utility.LineageObjectDirectDependency
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

            INSERT INTO ' + CAST(QUOTENAME(@UtilitySchemaDatabase) AS NVARCHAR(MAX)) + '.Utility.LineageObjectDirectDependency
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
            WHERE t.is_ms_shipped = 0;
            ';

            --------------------------------------------------------------------
            -- Debug: Print SQL for first database only (to avoid spam)
            --------------------------------------------------------------------
            IF @DatabaseName = 'AdventureWorks2017'
            BEGIN
                PRINT '=== SQL TO BE EXECUTED FOR AdventureWorks2017 ===';
                PRINT @SQL;
                PRINT '=== END SQL ===';
            END
            
            EXEC sys.sp_executesql @SQL;
        END TRY
        BEGIN CATCH
            PRINT 'Error processing dependencies for database: ' + @DatabaseName;
            PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(10));
            PRINT 'Error Message: ' + ERROR_MESSAGE();
            PRINT 'Error Line: ' + CAST(ERROR_LINE() AS VARCHAR(10));
        END CATCH
        
        --------------------------------------------------------------------
        -- Debug output: show progress
        --------------------------------------------------------------------
        DECLARE @RowCount INT;
        SELECT @RowCount = COUNT(*) 
        FROM Utility.LineageObjectDirectDependency 
        WHERE SourceDatabase = @DatabaseName;

        PRINT 'Processed database: ' + @DatabaseName 
              + ' - Dependencies captured: ' + CAST(@RowCount AS VARCHAR(10));
        
        FETCH NEXT FROM db_cursor INTO @DatabaseName;
    END
    
    CLOSE db_cursor;
    DEALLOCATE db_cursor;

    declare @ServerforMerge varchar(max) = (select @@SERVERNAME)

    Insert into Utility.LineageObjectDirectDependency
        (
        SourceServer
        , SourceDatabase
        , SourceSchema
        , SourceObject
        , SourceType
        , TargetServer
        , TargetDatabase
        , TargetSchema
        , TargetObject
        , TargetType
        , DependencyType
        , IsSchemabound
        , Level
        )

        select
            SourceServer  = @ServerforMerge
            , SourceDatabase = SourceDatabaseName
            , SourceSchema = SourceSchemaName
            , SourceObject = SourceObjectName
            , SourceType = SourceObjectType
            , TargetServer = @ServerforMerge
            , TatargetDatabase = ProcessDatabaseName
            , TargetSchema = ProcessSchemaName
            , TargetObject = ProcessObjectName
            , TargetType = ProcessObjectType
            , DependencyType = 'Direct'
            , [IsSchemabound] = 0
            , [Level] = 1
        from
	        SQLTools.Utility.DynamicMerge

        UNION ALL

        select
            SourceServer  = @ServerforMerge
            , SourceDatabase = ProcessDatabaseName
            , SourceSchema = ProcessSchemaName
            , SourceObject = ProcessObjectName
            , SourceType = ProcessObjectType
            , TargetServer = @ServerforMerge
            , TatargetDatabase = TargetDatabaseName
            , TargetSchema = TargetSchemaName
            , TargetObject = TargetObjectName
            , TargetType = TargetObjectType
            , DependencyType = 'Direct'
            , [IsSchemabound] = 0
            , [Level] = 1
        from
	        SQLTools.Utility.DynamicMerge
  
  ;
END
GO