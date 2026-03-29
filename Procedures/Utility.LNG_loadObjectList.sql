IF OBJECT_ID('Utility.LNG_loadObjectList', 'P') IS NOT NULL
    DROP PROCEDURE Utility.LNG_loadObjectList;

GO

CREATE PROCEDURE Utility.LNG_loadObjectList
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @CursorSQL NVARCHAR(MAX);
    DECLARE @DatabaseName NVARCHAR(128);
    -- Update @UtilitySchemaDatabase with the name of the Database you are deploying your Utility schema and LNG Objects to
    DECLARE @UtilitySchemaDatabase sysname = 'YourValue';

    TRUNCATE TABLE Utility.LNG_ObjectList;

    SET @CursorSQL = N'
        DECLARE db_cursor CURSOR FOR
        SELECT d.name 
        FROM sys.databases d
        WHERE d.state_desc = ''ONLINE'' 
            AND HAS_DBACCESS(d.name) = 1
            AND NOT EXISTS (
                SELECT 1 
                FROM ' + CAST(QUOTENAME(@UtilitySchemaDatabase) AS NVARCHAR(MAX)) + '.Utility.LNG_DatabaseExclusions de
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
            -- Build dynamic SQL for object list extraction
            --------------------------------------------------------------------
            SET @SQL = N'
            INSERT INTO ' + CAST(QUOTENAME(@UtilitySchemaDatabase) AS NVARCHAR(MAX)) + '.Utility.LNG_ObjectList 
                (ObjectID,ServerName, DatabaseName, SchemaName, ObjectName, ObjectType, ObjectTypeName, CreateDate, ModifyDate)
            SELECT 
                o.object_id AS ObjectID,
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
                ''SN'', -- Synonym
                ''SO'',  -- Sequence Object
                ''FN'', -- Scalar Function
                ''IF'', -- Inline Table Function
                ''TF'' -- Table Function           
                )
            AND o.is_ms_shipped = 0;
            ';
            
            EXEC sys.sp_executesql @SQL;
        END TRY
        BEGIN CATCH
            PRINT 'Error processing database: ' + @DatabaseName;
            PRINT ERROR_MESSAGE();
        END CATCH
        
        FETCH NEXT FROM db_cursor INTO @DatabaseName;
    END
    
    CLOSE db_cursor;
    DEALLOCATE db_cursor;
    
   ;
END
GO
