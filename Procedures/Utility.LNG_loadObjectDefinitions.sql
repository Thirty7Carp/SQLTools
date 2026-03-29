IF OBJECT_ID('Utility.LNG_loadObjectDefinitions', 'P') IS NOT NULL
    DROP PROCEDURE Utility.LNG_loadObjectDefinitions;

GO

Create PROCEDURE [Utility].[LNG_loadObjectDefinitions]

AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DatabaseName NVARCHAR(128);
    DECLARE @SchemaName NVARCHAR(128);
    DECLARE @ObjectID INT;
    DECLARE @ObjectName NVARCHAR(256);
    DECLARE @ObjectType NVARCHAR(60);
    DECLARE @SQL NVARCHAR(MAX);

    TRUNCATE TABLE Utility.LNG_ObjectDefinitions;

    DECLARE obj_cursor CURSOR FOR
    SELECT DatabaseName, SchemaName, ObjectID, ObjectName, ObjectType
    FROM Utility.LNG_ObjectList
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

            INSERT INTO ' + CAST(QUOTENAME(DB_NAME()) AS NVARCHAR(MAX)) + '.Utility.LNG_ObjectDefinitions
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

        PRINT 'Loaded Definition for ' + @DatabaseName + '.' + CAST(@ObjectID AS NVARCHAR(20));

        FETCH NEXT FROM obj_cursor INTO @DatabaseName, @SchemaName, @ObjectID, @ObjectName, @ObjectType;
    END;

    CLOSE obj_cursor;
    DEALLOCATE obj_cursor;
END;
GO