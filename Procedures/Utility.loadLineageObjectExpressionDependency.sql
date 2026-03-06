CREATE PROCEDURE [Utility].[LoadLineageObjectExpressionDependency]
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE Utility.LineageObjectExpressionDependency;

    DECLARE @DatabaseName NVARCHAR(128);
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @UtilitySchemaDatabase SYSNAME = DB_NAME();

    DECLARE db_cursor CURSOR FOR
        SELECT d.name
        FROM sys.databases d
        WHERE d.state_desc = 'ONLINE'
            AND HAS_DBACCESS(d.name) = 1
            AND NOT EXISTS (
                SELECT 1
                FROM Utility.LineageDatabaseExclusions de
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
                INSERT INTO ' + CAST(QUOTENAME(@UtilitySchemaDatabase) AS NVARCHAR(MAX)) + '.Utility.LineageObjectExpressionDependency
                    (
                    ReferencingObjectID,
                    ReferencingServer,
                    ReferencingDatabase,
                    ReferencingSchema,
                    ReferencingObject,
                    ReferencingObjectType,
                    referenced_id,
                    referenced_server_name,
                    referenced_database_name,
                    referenced_schema_name,
                    referenced_entity_name,
                    ReferencedObjectType,
                    is_ambiguous
                    )
                SELECT
                    ReferencingObjectID = sed.referencing_id,
                    ReferencingServer = @@SERVERNAME,
                    ReferencingDatabase = ''' + @DatabaseName + ''',
                    ReferencingSchema = s.name,
                    ReferencingObject = o.name,
                    ReferencingObjectType = o.type_desc,
                    referenced_id = sed.referenced_id,
                    referenced_server_name = ISNULL(sed.referenced_server_name, @@SERVERNAME),
                    referenced_database_name = ISNULL(sed.referenced_database_name, ''' + @DatabaseName + '''),
                    referenced_schema_name = COALESCE(sed.referenced_schema_name, rs.name, ''dbo''),
                    referenced_entity_name = sed.referenced_entity_name,
                    ReferencedObjectType = ro.type_desc,
                    is_ambiguous = sed.is_ambiguous
                FROM
                    [' + @DatabaseName + '].sys.sql_expression_dependencies sed
                    INNER JOIN [' + @DatabaseName + '].sys.objects o
                        ON sed.referencing_id = o.object_id
                    INNER JOIN [' + @DatabaseName + '].sys.schemas s
                        ON o.schema_id = s.schema_id
                    LEFT JOIN [' + @DatabaseName + '].sys.objects ro
                        ON sed.referenced_id = ro.object_id
                    LEFT JOIN [' + @DatabaseName + '].sys.schemas rs
                        ON ro.schema_id = rs.schema_id
                WHERE
                    sed.referencing_minor_id = 0
                    AND NOT EXISTS (
                        SELECT 1
                        FROM ' + CAST(QUOTENAME(@UtilitySchemaDatabase) AS NVARCHAR(MAX)) + '.Utility.LineageDatabaseExclusions de
                        WHERE de.IsActive = 1
                            AND (de.ServerName IS NULL OR de.ServerName = @@SERVERNAME)
                            AND ISNULL(sed.referenced_database_name, ''' + @DatabaseName + ''') LIKE de.DatabaseName
                    );
            ';

            EXEC sys.sp_executesql @SQL;

            DECLARE @RowCount INT;
            SELECT @RowCount = COUNT(*)
            FROM Utility.LineageObjectExpressionDependency
            WHERE ReferencingDatabase = @DatabaseName;

            PRINT 'Processed database: ' + @DatabaseName + ' - Dependencies captured: ' + CAST(@RowCount AS VARCHAR(20));

        END TRY
        BEGIN CATCH
            PRINT 'Error processing database: ' + @DatabaseName;
            PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(10));
            PRINT 'Error Message: ' + ERROR_MESSAGE();
            PRINT 'Error Line: ' + CAST(ERROR_LINE() AS VARCHAR(10));
        END CATCH

        FETCH NEXT FROM db_cursor INTO @DatabaseName;
    END

    CLOSE db_cursor;
    DEALLOCATE db_cursor;

END
GO