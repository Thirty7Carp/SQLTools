USE [Meta]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[loadObjectColumns]
AS
BEGIN
    SET NOCOUNT ON;

    -- Clear out the destination table before repopulating
    TRUNCATE TABLE Meta.dbo.ObjectColumns;

    DECLARE
        @DatabaseName SYSNAME,
        @SQL          NVARCHAR(MAX);

    -- Cursor only over DatabaseName
    DECLARE db_cursor CURSOR FOR
    SELECT DISTINCT DatabaseName
    FROM [Meta].[dbo].[ObjectAll];

    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @DatabaseName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Build dynamic SQL to insert into Meta.dbo.ObjectColumns
        SET @SQL = '
            INSERT INTO Meta.dbo.ObjectColumns (DatabaseName, TableName, ColumnName, ObjectID)
            SELECT 
                   ''' + @DatabaseName + ''' AS DatabaseName,
                   o.name AS TableName,
                   c.name AS ColumnName,
                   o.object_id AS ObjectID
            FROM ' + QUOTENAME(@DatabaseName) + '.sys.columns c
            INNER JOIN ' + QUOTENAME(@DatabaseName) + '.sys.objects o
                ON c.object_id = o.object_id
            WHERE
                o.type IN (''U'',''V'',''ET'',''TF'',''IF'')';  -- tables, views, external tables, TVFs

        EXEC sp_executesql @SQL;

        -- Print confirmation after loading each database
        PRINT 'Loaded column names for all objects on ' + @DatabaseName + ' database';

        FETCH NEXT FROM db_cursor INTO @DatabaseName;
    END;

    CLOSE db_cursor;
    DEALLOCATE db_cursor;
END;
GO
