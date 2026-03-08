CREATE PROCEDURE Utility.LoadLineageObjectParsedDependency
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE Utility.LineageObjectParsedDependency;

    DECLARE @SourceServer NVARCHAR(128);
    DECLARE @SourceDatabase NVARCHAR(128);
    DECLARE @SourceSchema NVARCHAR(128);
    DECLARE @SourceObject NVARCHAR(128);
    DECLARE @SourceType NVARCHAR(60);
    DECLARE @Definition NVARCHAR(MAX);
    DECLARE @DefLen INT;
    DECLARE @SearchPos INT;
    DECLARE @TokenStart INT;
    DECLARE @TokenEnd INT;
    DECLARE @ObjectRef NVARCHAR(500);
    DECLARE @FromPos INT;
    DECLARE @JoinPos INT;
    DECLARE @ResolvedRef NVARCHAR(500);
    DECLARE @NextToken NVARCHAR(128);
    DECLARE @DDLPos INT;
    DECLARE @AliasTable TABLE (Alias NVARCHAR(128), ObjectRef NVARCHAR(500));

    DECLARE @DDLKeywords TABLE (
        Keyword       NVARCHAR(50),
        OperationType NVARCHAR(20)
    )

    INSERT INTO @DDLKeywords VALUES
        (' CREATE TABLE ',     'CREATE'),
        (' CREATE VIEW ',      'CREATE'),
        (' CREATE PROCEDURE ', 'CREATE'),
        (' CREATE PROC ',      'CREATE'),
        (' CREATE FUNCTION ',  'CREATE'),
        (' ALTER TABLE ',      'ALTER'),
        (' ALTER VIEW ',       'ALTER'),
        (' ALTER PROCEDURE ',  'ALTER'),
        (' ALTER PROC ',       'ALTER'),
        (' ALTER FUNCTION ',   'ALTER'),
        (' DROP TABLE ',       'DROP'),
        (' DROP VIEW ',        'DROP'),
        (' DROP PROCEDURE ',   'DROP'),
        (' DROP PROC ',        'DROP'),
        (' DROP FUNCTION ',    'DROP'),
        (' TRUNCATE TABLE ',   'TRUNCATE')

    DECLARE @DDLKeyword  NVARCHAR(50)
    DECLARE @DDLOpType   NVARCHAR(20)

    DECLARE cur CURSOR FOR
        SELECT
            ServerName,
            DatabaseName,
            SchemaName,
            ObjectName,
            ObjectType,
            ObjectDefinition
        FROM
            Utility.LineageObjectDefinitions
        WHERE
            ObjectDefinition IS NOT NULL;

    OPEN cur;
    FETCH NEXT FROM cur INTO @SourceServer, @SourceDatabase, @SourceSchema, @SourceObject, @SourceType, @Definition;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SearchPos = 1;
        SET @DefLen = LEN(@Definition);

        DELETE FROM @AliasTable;

        --------------------------------------------------------------------
        -- Build alias map from FROM and JOIN clauses
        --------------------------------------------------------------------
        SET @SearchPos = 1;

        WHILE @SearchPos <= @DefLen
        BEGIN
            SET @FromPos = CHARINDEX(' FROM ', @Definition, @SearchPos);
            SET @JoinPos = CHARINDEX(' JOIN ', @Definition, @SearchPos);

            IF @FromPos = 0 AND @JoinPos = 0
                BREAK;

            IF @FromPos > 0 AND (@JoinPos = 0 OR @FromPos < @JoinPos)
                SET @SearchPos = @FromPos + 6;
            ELSE
                SET @SearchPos = @JoinPos + 6;

            SET @TokenStart = @SearchPos;
            SET @TokenEnd = @SearchPos;

            WHILE @TokenEnd <= @DefLen
                AND SUBSTRING(@Definition, @TokenEnd, 1) != ' '
                AND SUBSTRING(@Definition, @TokenEnd, 1) != ','
                AND SUBSTRING(@Definition, @TokenEnd, 1) != '('
            BEGIN
                SET @TokenEnd = @TokenEnd + 1;
            END

            SET @ObjectRef = SUBSTRING(@Definition, @TokenStart, @TokenEnd - @TokenStart);
            SET @SearchPos = @TokenEnd + 1;

            IF LEN(@ObjectRef) > 0 AND PARSENAME(@ObjectRef, 1) IS NOT NULL
            BEGIN
                WHILE @SearchPos <= @DefLen AND SUBSTRING(@Definition, @SearchPos, 1) = ' '
                    SET @SearchPos = @SearchPos + 1;

                SET @TokenStart = @SearchPos;
                SET @TokenEnd = @SearchPos;

                WHILE @TokenEnd <= @DefLen
                    AND SUBSTRING(@Definition, @TokenEnd, 1) != ' '
                    AND SUBSTRING(@Definition, @TokenEnd, 1) != ','
                BEGIN
                    SET @TokenEnd = @TokenEnd + 1;
                END

                SET @NextToken = SUBSTRING(@Definition, @TokenStart, @TokenEnd - @TokenStart);

                IF UPPER(@NextToken) = 'AS'
                BEGIN
                    SET @SearchPos = @TokenEnd + 1;
                    SET @TokenStart = @SearchPos;
                    SET @TokenEnd = @SearchPos;

                    WHILE @TokenEnd <= @DefLen
                        AND SUBSTRING(@Definition, @TokenEnd, 1) != ' '
                        AND SUBSTRING(@Definition, @TokenEnd, 1) != ','
                    BEGIN
                        SET @TokenEnd = @TokenEnd + 1;
                    END

                    SET @NextToken = SUBSTRING(@Definition, @TokenStart, @TokenEnd - @TokenStart);
                END

                IF LEN(@NextToken) > 0
                    AND UPPER(@NextToken) NOT IN ('WHERE', 'ON', 'SET', 'INNER', 'LEFT', 'RIGHT',
                                                   'FULL', 'CROSS', 'JOIN', 'GROUP', 'ORDER', 'HAVING')
                BEGIN
                    INSERT INTO @AliasTable (Alias, ObjectRef)
                    VALUES (@NextToken, @ObjectRef);
                END
            END
        END

        --------------------------------------------------------------------
        -- SELECT parser
        --------------------------------------------------------------------
        SET @SearchPos = 1;

        WHILE @SearchPos <= @DefLen
        BEGIN
            SET @FromPos = CHARINDEX(' FROM ', @Definition, @SearchPos);
            SET @JoinPos = CHARINDEX(' JOIN ', @Definition, @SearchPos);

            IF @FromPos = 0 AND @JoinPos = 0
                BREAK;

            IF @FromPos > 0 AND (@JoinPos = 0 OR @FromPos < @JoinPos)
            BEGIN
                SET @SearchPos = @FromPos + 6;

                WHILE @SearchPos <= @DefLen
                BEGIN
                    WHILE @SearchPos <= @DefLen AND SUBSTRING(@Definition, @SearchPos, 1) = ' '
                        SET @SearchPos = @SearchPos + 1;

                    SET @TokenStart = @SearchPos;
                    SET @TokenEnd = @SearchPos;

                    WHILE @TokenEnd <= @DefLen
                        AND SUBSTRING(@Definition, @TokenEnd, 1) != ' '
                        AND SUBSTRING(@Definition, @TokenEnd, 1) != ','
                        AND SUBSTRING(@Definition, @TokenEnd, 1) != '('
                    BEGIN
                        SET @TokenEnd = @TokenEnd + 1;
                    END

                    SET @ObjectRef = SUBSTRING(@Definition, @TokenStart, @TokenEnd - @TokenStart);

                    IF UPPER(@ObjectRef) IN ('WHERE', 'JOIN', 'INNER', 'LEFT', 'RIGHT', 'FULL',
                                             'CROSS', 'GROUP', 'ORDER', 'HAVING', 'ON', 'SET',
                                             'UNION', 'EXCEPT', 'INTERSECT')
                        BREAK;

                    IF LEN(@ObjectRef) > 0 AND PARSENAME(@ObjectRef, 1) IS NOT NULL
                    BEGIN
                        INSERT INTO Utility.LineageObjectParsedDependency
                            (SourceServer, SourceDatabase, SourceSchema, SourceObject, OperationType,
                             TargetServer, TargetDatabase, TargetSchema, TargetObject)
                        VALUES
                            (@SourceServer, @SourceDatabase, @SourceSchema, @SourceObject, 'SELECT',
                             ISNULL(PARSENAME(@ObjectRef, 4), @SourceServer),
                             ISNULL(PARSENAME(@ObjectRef, 3), @SourceDatabase),
                             ISNULL(PARSENAME(@ObjectRef, 2), 'dbo'),
                             PARSENAME(@ObjectRef, 1));
                    END

                    SET @SearchPos = @TokenEnd;

                    IF @SearchPos <= @DefLen AND SUBSTRING(@Definition, @SearchPos, 1) = ','
                    BEGIN
                        SET @SearchPos = @SearchPos + 1;
                    END
                    ELSE IF @SearchPos <= @DefLen AND SUBSTRING(@Definition, @SearchPos, 1) = ' '
                    BEGIN
                        SET @SearchPos = @SearchPos + 1;

                        WHILE @SearchPos <= @DefLen AND SUBSTRING(@Definition, @SearchPos, 1) = ' '
                            SET @SearchPos = @SearchPos + 1;

                        SET @TokenStart = @SearchPos;
                        SET @TokenEnd = @SearchPos;

                        WHILE @TokenEnd <= @DefLen
                            AND SUBSTRING(@Definition, @TokenEnd, 1) != ' '
                            AND SUBSTRING(@Definition, @TokenEnd, 1) != ','
                        BEGIN
                            SET @TokenEnd = @TokenEnd + 1;
                        END

                        SET @NextToken = UPPER(SUBSTRING(@Definition, @TokenStart, @TokenEnd - @TokenStart));

                        IF @NextToken IN ('WHERE', 'JOIN', 'INNER', 'LEFT', 'RIGHT', 'FULL',
                                          'CROSS', 'GROUP', 'ORDER', 'HAVING', 'ON', 'SET',
                                          'UNION', 'EXCEPT', 'INTERSECT', 'AS')
                            BREAK;

                        SET @SearchPos = @TokenEnd;

                        WHILE @SearchPos <= @DefLen AND SUBSTRING(@Definition, @SearchPos, 1) = ' '
                            SET @SearchPos = @SearchPos + 1;

                        IF @SearchPos <= @DefLen AND SUBSTRING(@Definition, @SearchPos, 1) = ','
                            SET @SearchPos = @SearchPos + 1;
                        ELSE
                            BREAK;
                    END
                    ELSE
                        BREAK;
                END
            END
            ELSE
            BEGIN
                SET @SearchPos = @JoinPos + 6;

                SET @TokenStart = @SearchPos;
                SET @TokenEnd = @SearchPos;

                WHILE @TokenEnd <= @DefLen
                    AND SUBSTRING(@Definition, @TokenEnd, 1) != ' '
                    AND SUBSTRING(@Definition, @TokenEnd, 1) != ','
                    AND SUBSTRING(@Definition, @TokenEnd, 1) != '('
                BEGIN
                    SET @TokenEnd = @TokenEnd + 1;
                END

                SET @ObjectRef = SUBSTRING(@Definition, @TokenStart, @TokenEnd - @TokenStart);

                IF LEN(@ObjectRef) > 0 AND PARSENAME(@ObjectRef, 1) IS NOT NULL
                BEGIN
                    INSERT INTO Utility.LineageObjectParsedDependency
                        (SourceServer, SourceDatabase, SourceSchema, SourceObject, OperationType,
                         TargetServer, TargetDatabase, TargetSchema, TargetObject)
                    VALUES
                        (@SourceServer, @SourceDatabase, @SourceSchema, @SourceObject, 'SELECT',
                         ISNULL(PARSENAME(@ObjectRef, 4), @SourceServer),
                         ISNULL(PARSENAME(@ObjectRef, 3), @SourceDatabase),
                         ISNULL(PARSENAME(@ObjectRef, 2), 'dbo'),
                         PARSENAME(@ObjectRef, 1));
                END

                SET @SearchPos = @TokenEnd;
            END
        END

        --------------------------------------------------------------------
        -- INSERT INTO parser
        --------------------------------------------------------------------
        SET @SearchPos = 1;

        WHILE @SearchPos <= @DefLen
        BEGIN
            DECLARE @InsertPos INT = CHARINDEX(' INSERT INTO ', @Definition, @SearchPos);

            IF @InsertPos = 0
                BREAK;

            SET @SearchPos = @InsertPos + 13;

            SET @TokenStart = @SearchPos;
            SET @TokenEnd = @SearchPos;

            WHILE @TokenEnd <= @DefLen
                AND SUBSTRING(@Definition, @TokenEnd, 1) != ' '
                AND SUBSTRING(@Definition, @TokenEnd, 1) != ','
                AND SUBSTRING(@Definition, @TokenEnd, 1) != '('
            BEGIN
                SET @TokenEnd = @TokenEnd + 1;
            END

            SET @ObjectRef = SUBSTRING(@Definition, @TokenStart, @TokenEnd - @TokenStart);

            IF LEN(@ObjectRef) > 0 AND PARSENAME(@ObjectRef, 1) IS NOT NULL
            BEGIN
                INSERT INTO Utility.LineageObjectParsedDependency
                    (SourceServer, SourceDatabase, SourceSchema, SourceObject, OperationType,
                     TargetServer, TargetDatabase, TargetSchema, TargetObject)
                VALUES
                    (@SourceServer, @SourceDatabase, @SourceSchema, @SourceObject, 'INSERT',
                     ISNULL(PARSENAME(@ObjectRef, 4), @SourceServer),
                     ISNULL(PARSENAME(@ObjectRef, 3), @SourceDatabase),
                     ISNULL(PARSENAME(@ObjectRef, 2), 'dbo'),
                     PARSENAME(@ObjectRef, 1));
            END

            SET @SearchPos = @TokenEnd;
        END

        --------------------------------------------------------------------
        -- SELECT INTO parser
        --------------------------------------------------------------------
        SET @SearchPos = 1;

        WHILE @SearchPos <= @DefLen
        BEGIN
            DECLARE @SelectIntoPos INT = CHARINDEX(' INTO ', @Definition, @SearchPos);

            IF @SelectIntoPos = 0
                BREAK;

            DECLARE @PrecedingText NVARCHAR(20) = LTRIM(RTRIM(SUBSTRING(@Definition, @SelectIntoPos - 10, 10)));

            IF @PrecedingText NOT LIKE '%INSERT%'
            BEGIN
                SET @SearchPos = @SelectIntoPos + 6;

                SET @TokenStart = @SearchPos;
                SET @TokenEnd = @SearchPos;

                WHILE @TokenEnd <= @DefLen
                    AND SUBSTRING(@Definition, @TokenEnd, 1) != ' '
                    AND SUBSTRING(@Definition, @TokenEnd, 1) != ','
                    AND SUBSTRING(@Definition, @TokenEnd, 1) != '('
                BEGIN
                    SET @TokenEnd = @TokenEnd + 1;
                END

                SET @ObjectRef = SUBSTRING(@Definition, @TokenStart, @TokenEnd - @TokenStart);

                IF LEN(@ObjectRef) > 0 AND PARSENAME(@ObjectRef, 1) IS NOT NULL
                BEGIN
                    INSERT INTO Utility.LineageObjectParsedDependency
                        (SourceServer, SourceDatabase, SourceSchema, SourceObject, OperationType,
                         TargetServer, TargetDatabase, TargetSchema, TargetObject)
                    VALUES
                        (@SourceServer, @SourceDatabase, @SourceSchema, @SourceObject, 'INSERT',
                         ISNULL(PARSENAME(@ObjectRef, 4), @SourceServer),
                         ISNULL(PARSENAME(@ObjectRef, 3), @SourceDatabase),
                         ISNULL(PARSENAME(@ObjectRef, 2), 'dbo'),
                         PARSENAME(@ObjectRef, 1));
                END

                SET @SearchPos = @TokenEnd;
            END
            ELSE
                SET @SearchPos = @SelectIntoPos + 6;
        END

        --------------------------------------------------------------------
        -- UPDATE parser with alias resolution
        --------------------------------------------------------------------
        SET @SearchPos = 1;

        WHILE @SearchPos <= @DefLen
        BEGIN
            DECLARE @UpdatePos INT = CHARINDEX(' UPDATE ', @Definition, @SearchPos);

            IF @UpdatePos = 0
                BREAK;

            SET @SearchPos = @UpdatePos + 8;

            SET @TokenStart = @SearchPos;
            SET @TokenEnd = @SearchPos;

            WHILE @TokenEnd <= @DefLen
                AND SUBSTRING(@Definition, @TokenEnd, 1) != ' '
                AND SUBSTRING(@Definition, @TokenEnd, 1) != ','
                AND SUBSTRING(@Definition, @TokenEnd, 1) != '('
            BEGIN
                SET @TokenEnd = @TokenEnd + 1;
            END

            SET @ObjectRef = SUBSTRING(@Definition, @TokenStart, @TokenEnd - @TokenStart);

            SET @ResolvedRef = NULL;
            SELECT @ResolvedRef = ObjectRef FROM @AliasTable WHERE Alias = @ObjectRef;
            IF @ResolvedRef IS NOT NULL
                SET @ObjectRef = @ResolvedRef;

            IF LEN(@ObjectRef) > 0 AND PARSENAME(@ObjectRef, 1) IS NOT NULL
            BEGIN
                INSERT INTO Utility.LineageObjectParsedDependency
                    (SourceServer, SourceDatabase, SourceSchema, SourceObject, OperationType,
                     TargetServer, TargetDatabase, TargetSchema, TargetObject)
                VALUES
                    (@SourceServer, @SourceDatabase, @SourceSchema, @SourceObject, 'UPDATE',
                     ISNULL(PARSENAME(@ObjectRef, 4), @SourceServer),
                     ISNULL(PARSENAME(@ObjectRef, 3), @SourceDatabase),
                     ISNULL(PARSENAME(@ObjectRef, 2), 'dbo'),
                     PARSENAME(@ObjectRef, 1));
            END

            SET @SearchPos = @TokenEnd;
        END

        --------------------------------------------------------------------
        -- DELETE parser with alias resolution
        --------------------------------------------------------------------
        SET @SearchPos = 1;

        WHILE @SearchPos <= @DefLen
        BEGIN
            DECLARE @DeletePos INT = CHARINDEX(' DELETE ', @Definition, @SearchPos);

            IF @DeletePos = 0
                BREAK;

            SET @SearchPos = @DeletePos + 8;

            SET @TokenStart = @SearchPos;
            SET @TokenEnd = @SearchPos;

            WHILE @TokenEnd <= @DefLen
                AND SUBSTRING(@Definition, @TokenEnd, 1) != ' '
                AND SUBSTRING(@Definition, @TokenEnd, 1) != ','
                AND SUBSTRING(@Definition, @TokenEnd, 1) != '('
            BEGIN
                SET @TokenEnd = @TokenEnd + 1;
            END

            SET @ObjectRef = SUBSTRING(@Definition, @TokenStart, @TokenEnd - @TokenStart);

            IF UPPER(@ObjectRef) = 'FROM'
            BEGIN
                SET @SearchPos = @TokenEnd + 1;
                SET @TokenStart = @SearchPos;
                SET @TokenEnd = @SearchPos;

                WHILE @TokenEnd <= @DefLen
                    AND SUBSTRING(@Definition, @TokenEnd, 1) != ' '
                    AND SUBSTRING(@Definition, @TokenEnd, 1) != ','
                    AND SUBSTRING(@Definition, @TokenEnd, 1) != '('
                BEGIN
                    SET @TokenEnd = @TokenEnd + 1;
                END

                SET @ObjectRef = SUBSTRING(@Definition, @TokenStart, @TokenEnd - @TokenStart);
            END

            SET @ResolvedRef = NULL;
            SELECT @ResolvedRef = ObjectRef FROM @AliasTable WHERE Alias = @ObjectRef;
            IF @ResolvedRef IS NOT NULL
                SET @ObjectRef = @ResolvedRef;

            IF LEN(@ObjectRef) > 0 AND PARSENAME(@ObjectRef, 1) IS NOT NULL
            BEGIN
                INSERT INTO Utility.LineageObjectParsedDependency
                    (SourceServer, SourceDatabase, SourceSchema, SourceObject, OperationType,
                     TargetServer, TargetDatabase, TargetSchema, TargetObject)
                VALUES
                    (@SourceServer, @SourceDatabase, @SourceSchema, @SourceObject, 'DELETE',
                     ISNULL(PARSENAME(@ObjectRef, 4), @SourceServer),
                     ISNULL(PARSENAME(@ObjectRef, 3), @SourceDatabase),
                     ISNULL(PARSENAME(@ObjectRef, 2), 'dbo'),
                     PARSENAME(@ObjectRef, 1));
            END

            SET @SearchPos = @TokenEnd;
        END

        --------------------------------------------------------------------
        -- MERGE parser
        --------------------------------------------------------------------
        SET @SearchPos = 1;

        WHILE @SearchPos <= @DefLen
        BEGIN
            DECLARE @MergePos INT = CHARINDEX(' MERGE ', @Definition, @SearchPos);

            IF @MergePos = 0
                BREAK;

            SET @SearchPos = @MergePos + 7;

            SET @TokenStart = @SearchPos;
            SET @TokenEnd = @SearchPos;

            WHILE @TokenEnd <= @DefLen
                AND SUBSTRING(@Definition, @TokenEnd, 1) != ' '
            BEGIN
                SET @TokenEnd = @TokenEnd + 1;
            END

            DECLARE @MergeNext NVARCHAR(128) = SUBSTRING(@Definition, @TokenStart, @TokenEnd - @TokenStart);

            IF UPPER(@MergeNext) = 'INTO'
                SET @SearchPos = @TokenEnd + 1;

            SET @TokenStart = @SearchPos;
            SET @TokenEnd = @SearchPos;

            WHILE @TokenEnd <= @DefLen
                AND SUBSTRING(@Definition, @TokenEnd, 1) != ' '
                AND SUBSTRING(@Definition, @TokenEnd, 1) != ','
                AND SUBSTRING(@Definition, @TokenEnd, 1) != '('
            BEGIN
                SET @TokenEnd = @TokenEnd + 1;
            END

            SET @ObjectRef = SUBSTRING(@Definition, @TokenStart, @TokenEnd - @TokenStart);

            IF LEN(@ObjectRef) > 0 AND PARSENAME(@ObjectRef, 1) IS NOT NULL
            BEGIN
                INSERT INTO Utility.LineageObjectParsedDependency
                    (SourceServer, SourceDatabase, SourceSchema, SourceObject, OperationType,
                     TargetServer, TargetDatabase, TargetSchema, TargetObject)
                VALUES
                    (@SourceServer, @SourceDatabase, @SourceSchema, @SourceObject, 'MERGE',
                     ISNULL(PARSENAME(@ObjectRef, 4), @SourceServer),
                     ISNULL(PARSENAME(@ObjectRef, 3), @SourceDatabase),
                     ISNULL(PARSENAME(@ObjectRef, 2), 'dbo'),
                     PARSENAME(@ObjectRef, 1));
            END

            DECLARE @UsingPos INT = CHARINDEX(' USING ', @Definition, @TokenEnd);

            IF @UsingPos > 0
            BEGIN
                SET @SearchPos = @UsingPos + 7;

                SET @TokenStart = @SearchPos;
                SET @TokenEnd = @SearchPos;

                WHILE @TokenEnd <= @DefLen
                    AND SUBSTRING(@Definition, @TokenEnd, 1) != ' '
                    AND SUBSTRING(@Definition, @TokenEnd, 1) != ','
                    AND SUBSTRING(@Definition, @TokenEnd, 1) != '('
                BEGIN
                    SET @TokenEnd = @TokenEnd + 1;
                END

                SET @ObjectRef = SUBSTRING(@Definition, @TokenStart, @TokenEnd - @TokenStart);

                IF LEN(@ObjectRef) > 0 AND PARSENAME(@ObjectRef, 1) IS NOT NULL
                BEGIN
                    INSERT INTO Utility.LineageObjectParsedDependency
                        (SourceServer, SourceDatabase, SourceSchema, SourceObject, OperationType,
                         TargetServer, TargetDatabase, TargetSchema, TargetObject)
                    VALUES
                        (@SourceServer, @SourceDatabase, @SourceSchema, @SourceObject, 'SELECT',
                         ISNULL(PARSENAME(@ObjectRef, 4), @SourceServer),
                         ISNULL(PARSENAME(@ObjectRef, 3), @SourceDatabase),
                         ISNULL(PARSENAME(@ObjectRef, 2), 'dbo'),
                         PARSENAME(@ObjectRef, 1));
                END
            END

            SET @SearchPos = @TokenEnd;
        END

        --------------------------------------------------------------------
        -- DDL parser
        --------------------------------------------------------------------
        DECLARE ddl_cursor CURSOR FOR
            SELECT Keyword, OperationType FROM @DDLKeywords

        OPEN ddl_cursor
        FETCH NEXT FROM ddl_cursor INTO @DDLKeyword, @DDLOpType

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @DDLPos = CHARINDEX(@DDLKeyword, @Definition, 1)
            IF @DDLPos > 0
            BEGIN
                -- DATALENGTH returns bytes, /2 for NVARCHAR to get character count
                -- This correctly includes both leading and trailing spaces unlike LEN()
                SET @TokenStart = @DDLPos + DATALENGTH(@DDLKeyword) / 2
                SET @TokenEnd = @TokenStart

                WHILE @TokenEnd <= @DefLen
                    AND SUBSTRING(@Definition, @TokenEnd, 1) != ' '
                    AND SUBSTRING(@Definition, @TokenEnd, 1) != ','
                    AND SUBSTRING(@Definition, @TokenEnd, 1) != '('
                BEGIN
                    SET @TokenEnd = @TokenEnd + 1
                END

                SET @ObjectRef = SUBSTRING(@Definition, @TokenStart, @TokenEnd - @TokenStart)

                IF LEN(@ObjectRef) > 0 AND PARSENAME(@ObjectRef, 1) IS NOT NULL
                    INSERT INTO Utility.LineageObjectParsedDependency
                        (SourceServer, SourceDatabase, SourceSchema, SourceObject, OperationType,
                         TargetServer, TargetDatabase, TargetSchema, TargetObject)
                    VALUES
                        (@SourceServer, @SourceDatabase, @SourceSchema, @SourceObject, @DDLOpType,
                         ISNULL(PARSENAME(@ObjectRef, 4), @SourceServer),
                         ISNULL(PARSENAME(@ObjectRef, 3), @SourceDatabase),
                         ISNULL(PARSENAME(@ObjectRef, 2), 'dbo'),
                         PARSENAME(@ObjectRef, 1))
            END

            FETCH NEXT FROM ddl_cursor INTO @DDLKeyword, @DDLOpType
        END

        CLOSE ddl_cursor
        DEALLOCATE ddl_cursor

        --------------------------------------------------------------------
        -- EXECUTE parser
        --------------------------------------------------------------------
        SET @SearchPos = 1;

        WHILE @SearchPos <= @DefLen
        BEGIN
            DECLARE @ExecPos INT = CHARINDEX(' EXEC ', @Definition, @SearchPos);
            DECLARE @ExecutePos INT = CHARINDEX(' EXECUTE ', @Definition, @SearchPos);

            IF @ExecPos = 0 AND @ExecutePos = 0
                BREAK;

            IF @ExecPos > 0 AND (@ExecutePos = 0 OR @ExecPos < @ExecutePos)
                SET @SearchPos = @ExecPos + 6;
            ELSE
                SET @SearchPos = @ExecutePos + 9;

            SET @TokenStart = @SearchPos;
            SET @TokenEnd = @SearchPos;

            WHILE @TokenEnd <= @DefLen
                AND SUBSTRING(@Definition, @TokenEnd, 1) != ' '
                AND SUBSTRING(@Definition, @TokenEnd, 1) != ','
                AND SUBSTRING(@Definition, @TokenEnd, 1) != '('
            BEGIN
                SET @TokenEnd = @TokenEnd + 1;
            END

            SET @ObjectRef = SUBSTRING(@Definition, @TokenStart, @TokenEnd - @TokenStart);

            IF LEN(@ObjectRef) > 0 AND PARSENAME(@ObjectRef, 1) IS NOT NULL
            BEGIN
                INSERT INTO Utility.LineageObjectParsedDependency
                    (SourceServer, SourceDatabase, SourceSchema, SourceObject, OperationType,
                     TargetServer, TargetDatabase, TargetSchema, TargetObject)
                VALUES
                    (@SourceServer, @SourceDatabase, @SourceSchema, @SourceObject, 'EXECUTE',
                     ISNULL(PARSENAME(@ObjectRef, 4), @SourceServer),
                     ISNULL(PARSENAME(@ObjectRef, 3), @SourceDatabase),
                     ISNULL(PARSENAME(@ObjectRef, 2), 'dbo'),
                     PARSENAME(@ObjectRef, 1));
            END

            SET @SearchPos = @TokenEnd;
        END

        FETCH NEXT FROM cur INTO @SourceServer, @SourceDatabase, @SourceSchema, @SourceObject, @SourceType, @Definition;
    END

    CLOSE cur;
    DEALLOCATE cur;



END
GO