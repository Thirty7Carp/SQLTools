
create PROCEDURE [Utility].updateLineageObjectDefinitions_RemoveComments
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id INT, @sql NVARCHAR(MAX);
    DECLARE @ServerName varchar(128)
    DECLARE @DatabaseName NVARCHAR(128);
    Declare @SchemaName nvarchar(128);
    DECLARE @start INT, @end INT, @depth INT;

    DECLARE cur CURSOR FOR
        SELECT ServerName, DatabaseName, SchemaName, ObjectID, [ObjectDefinition]
        FROM Utility.LineageObjectDefinitions;

    OPEN cur;
    FETCH NEXT FROM cur INTO @ServerName, @DatabaseName, @SchemaName, @id, @sql;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -------------------------------------------------------------------
        -- Remove all balanced /* … */ blocks
        -------------------------------------------------------------------
        WHILE CHARINDEX('/*', @sql) > 0
        BEGIN
            SET @start = CHARINDEX('/*', @sql);
            SET @depth = 0;
            DECLARE @i INT = @start + 2;
            SET @end = 0;

            WHILE @i <= LEN(@sql)
            BEGIN
                IF SUBSTRING(@sql, @i, 2) = '/*'
                BEGIN
                    SET @depth = @depth + 1;
                    SET @i += 2;
                    CONTINUE;
                END
                ELSE IF SUBSTRING(@sql, @i, 2) = '*/'
                BEGIN
                    IF @depth = 0
                    BEGIN
                        SET @end = @i;
                        BREAK;
                    END
                    ELSE
                    BEGIN
                        SET @depth = @depth - 1;
                        SET @i += 2;
                        CONTINUE;
                    END
                END
                SET @i += 1;
            END

            IF @end > 0
                SET @sql = STUFF(@sql, @start, @end - @start + 2, '');
            ELSE
                BREAK; -- no matching close
        END

        -------------------------------------------------------------------
        -- Strip line comments (-- …) while preserving formatting
        -------------------------------------------------------------------
        ;WITH Lines AS (
            SELECT value AS Line
            FROM STRING_SPLIT(@sql, CHAR(10))
        )
        SELECT @sql = STRING_AGG(
                   CASE 
                       WHEN CHARINDEX('--', Line) > 0 
                       THEN LEFT(Line, CHARINDEX('--', Line) - 1)
                       ELSE Line
                   END, CHAR(10)
               )
        FROM Lines;

        -------------------------------------------------------------------
        -- Update the table with cleaned definition
        -------------------------------------------------------------------
        UPDATE Utility.LineageObjectDefinitions
        SET [ObjectDefinition] = @sql
        WHERE 
            ServerName = @ServerName
            and DatabaseName = @DatabaseName
            and ObjectID = @id;

        -- Print confirmation in requested format
        PRINT 'Cleaned Comments on ' + @Servername + '.' + @DatabaseName + '.' + @SchemaName + '.' + CAST(@id AS VARCHAR);

        FETCH NEXT FROM cur INTO @Servername, @DatabaseName, @SchemaName, @id, @sql;
    END

    CLOSE cur;
    DEALLOCATE cur;
END;
GO
