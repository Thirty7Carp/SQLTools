IF OBJECT_ID('Utility.LNG_updateObjectDefinitions_RemoveWhitespace', 'P') IS NOT NULL
    DROP PROCEDURE Utility.LNG_updateObjectDefinitions_RemoveWhitespace;

GO

CREATE PROCEDURE [Utility].[LNG_updateObjectDefinitions_RemoveWhitespace]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id INT;
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @ServerName VARCHAR(128);
    DECLARE @DatabaseName NVARCHAR(128);
    DECLARE @SchemaName NVARCHAR(128);

    DECLARE cur CURSOR FOR
        SELECT ServerName, DatabaseName, SchemaName, ObjectID, ObjectDefinition
        FROM Utility.LNG_ObjectDefinitions;

    OPEN cur;
    FETCH NEXT FROM cur INTO @ServerName, @DatabaseName, @SchemaName, @id, @sql;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Add space before semicolons
        SET @sql = REPLACE(@sql, ';', ' ;');

        -- Add space before bracket
        SET @sql = REPLACE(@sql, ')', ' )');

        -- Add space before commas
        SET @sql = REPLACE(@sql, ',', ' ,');

        -- Replace tabs with a space
        SET @sql = REPLACE(@sql, CHAR(9), ' ');

        -- Replace carriage returns with a space
        SET @sql = REPLACE(@sql, CHAR(13), ' ');

        -- Replace newlines with a space
        SET @sql = REPLACE(@sql, CHAR(10), ' ');

        -- Collapse multiple spaces down to a single space
        WHILE CHARINDEX('  ', @sql) > 0
        BEGIN
            SET @sql = REPLACE(@sql, '  ', ' ');
        END

        -- Trim leading and trailing spaces
        SET @sql = LTRIM(RTRIM(@sql));

        UPDATE Utility.LNG_ObjectDefinitions
        SET ObjectDefinition = @sql
        WHERE
            ServerName = @ServerName
            AND DatabaseName = @DatabaseName
            AND ObjectID = @id;

        PRINT 'Cleaned Whitespace on ' + @ServerName + '.' + @DatabaseName + '.' + @SchemaName + '.' + CAST(@id AS VARCHAR);

        FETCH NEXT FROM cur INTO @ServerName, @DatabaseName, @SchemaName, @id, @sql;
    END

    CLOSE cur;
    DEALLOCATE cur;

END
GO