CREATE PROCEDURE [Utility].[loadLineageObjectDefinitions]

AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DatabaseName NVARCHAR(128);
    DECLARE @SchemaName NVARCHAR(128);
    DECLARE @ObjectID INT;
    DECLARE @ObjectName NVARCHAR(256);
    DECLARE @ObjectType NVARCHAR(60);
    DECLARE @SQL NVARCHAR(MAX);

    -- Clear out old data if you want a fresh load each run
    TRUNCATE TABLE Utility.LineageObjectDefinitions;

    DECLARE obj_cursor CURSOR FOR
    SELECT DatabaseName, SchemaName, ObjectID, ObjectName, ObjectType
    FROM Utility.LineageObjectList
    WHERE ObjectTypeName IN (
        'CHECK_CONSTRAINT',
        'DEFAULT_CONSTRAINT',
        'SQL_SCALAR_FUNCTION',
        'SQL_STORED_PROCEDURE',
        'SQL_TABLE_VALUED_FUNCTION',
        'SQL_TRIGGER',
        'VIEW'
    );

    OPEN obj_cursor;
    FETCH NEXT FROM obj_cursor INTO @DatabaseName, @SchemaName, @ObjectID, @ObjectName, @ObjectType;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SQL = '
            USE [' + @DatabaseName + '];

            INSERT INTO ' + QUOTENAME(DB_NAME()) + '.Utility.LineageObjectDefinitions
                (ServerName, DatabaseName, SchemaName, ObjectID, ObjectName, ObjectType, ObjectDefinition)
            SELECT 
                ''' + @@SERVERNAME + ''',
                ''' + @DatabaseName + ''',
                ''' + @SchemaName + ''',
                ' + CAST(@ObjectID AS NVARCHAR(20)) + ',
                ''' + @ObjectName + ''',
                ''' + @ObjectType + ''',
                OBJECT_DEFINITION(' + CAST(@ObjectID AS NVARCHAR(20)) + ')
            FROM sys.objects
            WHERE object_id = ' + CAST(@ObjectID AS NVARCHAR(20)) + ';
        ';

        EXEC (@SQL);

        -- Print confirmation in the requested format
        PRINT 'Loaded Definition for ' + @DatabaseName + '.' + CAST(@ObjectID AS NVARCHAR(20));

        FETCH NEXT FROM obj_cursor INTO @DatabaseName, @SchemaName, @ObjectID, @ObjectName, @ObjectType;
    END;

    CLOSE obj_cursor;
    DEALLOCATE obj_cursor;
END;
GO