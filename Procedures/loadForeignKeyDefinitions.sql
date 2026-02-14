

CREATE PROCEDURE [dbo].[loadForeignKeyDefinitions]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DatabaseName NVARCHAR(128);
    DECLARE @SQL NVARCHAR(MAX);

    -- Only clear out old foreign key definitions
    DELETE FROM dbo.ObjectDefinitions
    WHERE ObjectType = 'FOREIGN_KEY_CONSTRAINT';

    DECLARE db_cursor CURSOR FOR
    SELECT name
    FROM sys.databases
    WHERE name NOT IN ('master','tempdb','model','msdb'); -- exclude system DBs

    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @DatabaseName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Build dynamic SQL to pull foreign key definitions
        SET @SQL = '
            USE [' + @DatabaseName + '];

            DECLARE @fk_object_id INT;

            DECLARE fk_cursor CURSOR FOR
            SELECT fk.object_id
            FROM sys.foreign_keys fk;

            OPEN fk_cursor;
            FETCH NEXT FROM fk_cursor INTO @fk_object_id;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO ' + QUOTENAME(DB_NAME()) + '.dbo.ObjectDefinitions
                    (DatabaseName, SchemaName, ObjectID, ObjectName, ObjectType, ObjectDefinition)
                SELECT
                    ''' + @DatabaseName + ''',
                    s.name,
                    fk.object_id,
                    fk.name,
                    ''FOREIGN_KEY_CONSTRAINT'',
                    ''ALTER TABLE '' + QUOTENAME(s.name) + ''.'' + QUOTENAME(tp.name) +
                    '' ADD CONSTRAINT '' + QUOTENAME(fk.name) +
                    '' FOREIGN KEY ('' + STUFF((
                        SELECT '','' + QUOTENAME(cp.name)
                        FROM sys.foreign_key_columns fkc2
                        JOIN sys.columns cp ON fkc2.parent_object_id = cp.object_id AND fkc2.parent_column_id = cp.column_id
                        WHERE fkc2.constraint_object_id = fk.object_id
                        FOR XML PATH(''''), TYPE).value(''.'', ''NVARCHAR(MAX)''),1,1,'''') + '')'' +
                    '' REFERENCES '' + QUOTENAME(rs.name) + ''.'' + QUOTENAME(rt.name) +
                    ''('' + STUFF((
                        SELECT '','' + QUOTENAME(cr.name)
                        FROM sys.foreign_key_columns fkc3
                        JOIN sys.columns cr ON fkc3.referenced_object_id = cr.object_id AND fkc3.referenced_column_id = cr.column_id
                        WHERE fkc3.constraint_object_id = fk.object_id
                        FOR XML PATH(''''), TYPE).value(''.'', ''NVARCHAR(MAX)''),1,1,'''') + '')''
                FROM sys.foreign_keys fk
                JOIN sys.tables tp ON fk.parent_object_id = tp.object_id
                JOIN sys.schemas s ON tp.schema_id = s.schema_id
                JOIN sys.tables rt ON fk.referenced_object_id = rt.object_id
                JOIN sys.schemas rs ON rt.schema_id = rs.schema_id
                WHERE fk.object_id = @fk_object_id;

                PRINT ''Loaded Foreign Key definition into ObjectDefinitions for ' + @DatabaseName + '.'' + CAST(@fk_object_id AS NVARCHAR(20));

                FETCH NEXT FROM fk_cursor INTO @fk_object_id;
            END;

            CLOSE fk_cursor;
            DEALLOCATE fk_cursor;
        ';

        EXEC (@SQL);

        FETCH NEXT FROM db_cursor INTO @DatabaseName;
    END;

    CLOSE db_cursor;
    DEALLOCATE db_cursor;
END;
GO
