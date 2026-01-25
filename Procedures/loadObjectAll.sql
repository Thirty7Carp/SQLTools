USE [Meta]
GO

/****** Object:  StoredProcedure [dbo].[loadObjectAll]    Script Date: 23/01/2026 2:35:21 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


create PROCEDURE [dbo].[loadObjectAll]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DatabaseName NVARCHAR(128);
    DECLARE @SQL NVARCHAR(MAX);


    -- Clear out old data if you want a fresh load each run
    TRUNCATE TABLE dbo.ObjectAll;

    DECLARE db_cursor CURSOR FOR
    SELECT name
    FROM sys.databases
    WHERE name NOT IN ('master','tempdb','model','msdb'); -- exclude system DBs if desired

    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @DatabaseName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SQL = '
            INSERT INTO ' + QUOTENAME(DB_NAME()) + '.dbo.ObjectAll ( DatabaseName, SchemaName, ObjectID, ObjectName, ObjectType)
            SELECT 
                ''' + @DatabaseName + ''',
                s.name,
                o.object_id,
                o.name,
                o.type_desc
            FROM 
                [' + @DatabaseName + '].sys.objects AS o INNER JOIN [' + @DatabaseName + '].sys.schemas AS s
                    ON o.schema_id = s.schema_id
            WHERE 
                s.name != ''sys''
                AND s.name != ''INFORMATION_SCHEMA'';
        ';

        PRINT 'Loaded Object List for ' + @DatabaseName + ' database';
        EXEC sp_executesql @SQL;

        FETCH NEXT FROM db_cursor INTO @DatabaseName;
    END;

    CLOSE db_cursor;
    DEALLOCATE db_cursor;
END;
GO


