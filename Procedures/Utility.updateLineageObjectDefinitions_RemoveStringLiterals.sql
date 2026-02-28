CREATE PROCEDURE [Utility].[updateLineageObjectDefinitions_RemoveStringLiterals]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id INT;
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @ServerName VARCHAR(128);
    DECLARE @DatabaseName NVARCHAR(128);
    DECLARE @SchemaName NVARCHAR(128);
    DECLARE @start INT;
    DECLARE @end INT;
    DECLARE @i INT;

    DECLARE cur CURSOR FOR
        SELECT ServerName, DatabaseName, SchemaName, ObjectID, ObjectDefinition
        FROM Utility.LineageObjectDefinitions;

    OPEN cur;
    FETCH NEXT FROM cur INTO @ServerName, @DatabaseName, @SchemaName, @id, @sql;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @i = 1;

        WHILE @i <= LEN(@sql)
        BEGIN
            -- Find the next opening single quote
            SET @start = CHARINDEX('''', @sql, @i);

            IF @start = 0
                BREAK;

            -- Find the closing single quote, accounting for escaped quotes ('')
            SET @i = @start + 1;

            WHILE @i <= LEN(@sql)
            BEGIN
                IF SUBSTRING(@sql, @i, 2) = ''''''
                BEGIN
                    -- Escaped quote, skip both characters
                    SET @i = @i + 2;
                    CONTINUE;
                END
                ELSE IF SUBSTRING(@sql, @i, 1) = ''''
                BEGIN
                    -- Closing quote found
                    SET @end = @i;
                    BREAK;
                END
                SET @i = @i + 1;
            END

            IF @end > @start
            BEGIN
                -- Remove everything from opening to closing quote inclusive
                SET @sql = STUFF(@sql, @start, @end - @start + 1, '');
                SET @i = @start;
            END
            ELSE
                BREAK;
        END

        UPDATE Utility.LineageObjectDefinitions
        SET ObjectDefinition = @sql
        WHERE
            ServerName = @ServerName
            AND DatabaseName = @DatabaseName
            AND ObjectID = @id;

        PRINT 'Cleaned String Literals on ' + @ServerName + '.' + @DatabaseName + '.' + @SchemaName + '.' + CAST(@id AS VARCHAR);

        FETCH NEXT FROM cur INTO @ServerName, @DatabaseName, @SchemaName, @id, @sql;
    END

    CLOSE cur;
    DEALLOCATE cur;
END;
GO