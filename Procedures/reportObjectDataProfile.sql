create PROCEDURE dbo.reportObjectDataProfile
    @ObjectName NVARCHAR(300)   -- e.g. 'AdventureWorks2017.Person.Person'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DatabaseName SYSNAME = PARSENAME(@ObjectName,3);
    DECLARE @SchemaName   SYSNAME = PARSENAME(@ObjectName,2);
    DECLARE @TableName    SYSNAME = PARSENAME(@ObjectName,1);

    DROP TABLE IF EXISTS #ColumnProfile;

    DECLARE @Columns TABLE (
        ColumnNumber INT,
        ColumnName SYSNAME,
        ColumnType SYSNAME,
        ColumnPrecision INT,
        ColumnLength INT,
        ColumnScale INT
    );

    -- Metadata query with corrected type and length logic
    DECLARE @MetaSQL NVARCHAR(MAX) = 
    'SELECT 
        ColumnNumber    = c.column_id,
        ColumnName      = c.name,
        ColumnType      = TYPE_NAME(c.system_type_id),
        ColumnPrecision = c.precision,
        ColumnLength    = CASE 
                              WHEN TYPE_NAME(c.system_type_id) IN (''nvarchar'',''nchar'') THEN c.max_length / 2
                              WHEN TYPE_NAME(c.system_type_id) IN (''varchar'',''char'',''text'',''ntext'') THEN c.max_length
                              ELSE NULL
                          END,
        ColumnScale     = c.scale
    FROM ' + QUOTENAME(@DatabaseName) + '.sys.columns c
    WHERE c.object_id = OBJECT_ID(''' + @DatabaseName + '.' + @SchemaName + '.' + @TableName + ''')
      AND TYPE_NAME(c.system_type_id) NOT IN (''xml'',''varbinary'',''image'',''geography'',''hierarchyid'');';

    INSERT INTO @Columns (ColumnNumber, ColumnName, ColumnType, ColumnPrecision, ColumnLength, ColumnScale)
    EXEC (@MetaSQL);

    CREATE TABLE #ColumnProfile (
        ColumnNumber INT,
        DatabaseName SYSNAME,
        SchemaName SYSNAME,
        TableName SYSNAME,
        ColumnName SYSNAME,
        Type SYSNAME,
        Length INT,
        Precision INT,
        Scale INT,
        TotalRows INT,
        MinValue NVARCHAR(MAX),
        MaxValue NVARCHAR(MAX),
        MostCommonValue NVARCHAR(MAX),
        MostCommonValueAppears INT,
        MostCommonValuePercentage FLOAT,
        DistinctValues INT,
        UniqueValues INT,
        UniquenessPercentage FLOAT,
        NullValues INT,
        NullPercentage FLOAT
    );

    DECLARE @ColNumber INT, @ColName SYSNAME, @ColType SYSNAME;
    DECLARE @ColPrecision INT, @ColLength INT, @ColScale INT;
    DECLARE @SQL NVARCHAR(MAX);

    DECLARE col_cursor CURSOR FOR
    SELECT ColumnNumber, ColumnName, ColumnType, ColumnPrecision, ColumnLength, ColumnScale
    FROM @Columns;

    OPEN col_cursor;
    FETCH NEXT FROM col_cursor INTO @ColNumber, @ColName, @ColType, @ColPrecision, @ColLength, @ColScale;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SQL = '
        INSERT INTO #ColumnProfile
        SELECT
            ColumnNumber      = ' + CAST(@ColNumber AS NVARCHAR(10)) + ',
            DatabaseName      = ''' + @DatabaseName + ''',
            SchemaName        = ''' + @SchemaName + ''',
            TableName         = ''' + @TableName + ''',
            ColumnName        = ''' + @ColName + ''',
            Type              = ''' + @ColType + ''',
            Length            = ' + COALESCE(CAST(@ColLength AS NVARCHAR(10)), 'NULL') + ',
            Precision         = ' + COALESCE(CAST(@ColPrecision AS NVARCHAR(10)), 'NULL') + ',
            Scale             = ' + COALESCE(CAST(@ColScale AS NVARCHAR(10)), 'NULL') + ',
            TotalRows         = COUNT(*),
            MinValue          = NULL,
            MaxValue          = NULL,
            MostCommonValue   = (
                SELECT 
                    CASE 
                        WHEN COUNT(*) >= 10 
                            THEN ''Limit (10) Reached: '' + STRING_AGG(ISNULL(CONVERT(NVARCHAR(MAX), tied.' + QUOTENAME(@ColName) + '), ''<NULL>''), '', '')
                        ELSE STRING_AGG(ISNULL(CONVERT(NVARCHAR(MAX), tied.' + QUOTENAME(@ColName) + '), ''<NULL>''), '', '')
                    END
                FROM (
                    SELECT TOP (10) ' + QUOTENAME(@ColName) + '
                    FROM (
                        SELECT ' + QUOTENAME(@ColName) + ', COUNT(*) AS cnt
                        FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + '
                        GROUP BY ' + QUOTENAME(@ColName) + '
                    ) AS counts
                    WHERE cnt = (
                        SELECT MAX(cnt)
                        FROM (
                            SELECT COUNT(*) AS cnt
                            FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + '
                            GROUP BY ' + QUOTENAME(@ColName) + '
                        ) AS maxcounts
                    )
                    ORDER BY ' + QUOTENAME(@ColName) + '
                ) AS tied
            ),
            MostCommonValueAppears = (
                SELECT TOP 1 cnt
                FROM (
                    SELECT COUNT(*) AS cnt
                    FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + '
                    GROUP BY ' + QUOTENAME(@ColName) + '
                ) AS counts
                ORDER BY cnt DESC
            ),
            MostCommonValuePercentage = (
                SELECT MAX(cnt) * 100.0 / NULLIF((SELECT COUNT(*) 
                                                  FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + '),0)
                FROM (
                    SELECT COUNT(*) AS cnt
                    FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + '
                    GROUP BY ' + QUOTENAME(@ColName) + '
                ) AS counts
            ),
            DistinctValues    = COUNT(DISTINCT ' + QUOTENAME(@ColName) + '),
            UniqueValues      = (
                SELECT COUNT(*) 
                FROM (
                    SELECT ' + QUOTENAME(@ColName) + '
                    FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + '
                    GROUP BY ' + QUOTENAME(@ColName) + '
                    HAVING COUNT(*) = 1
                ) AS uniques
            ),
            UniquenessPercentage = (
                SELECT COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) 
                                                  FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + '),0)
                FROM (
                    SELECT ' + QUOTENAME(@ColName) + '
                    FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + '
                    GROUP BY ' + QUOTENAME(@ColName) + '
                    HAVING COUNT(*) = 1
                ) AS uniques
            ),
            NullValues        = (
                SELECT COUNT(*) 
                FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + '
                WHERE ' + QUOTENAME(@ColName) + ' IS NULL
            ),
            NullPercentage    = (
                SELECT COUNT(*) * 100.0 / NULLIF(
                    (SELECT COUNT(*) 
                     FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + '), 0
                )
                FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + '
                WHERE ' + QUOTENAME(@ColName) + ' IS NULL
            )
        FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + ';';

        EXEC (@SQL);

        FETCH NEXT FROM col_cursor INTO @ColNumber, @ColName, @ColType, @ColPrecision, @ColLength, @ColScale;
    END;

    CLOSE col_cursor;
    DEALLOCATE col_cursor;
    
    DECLARE @ColNumber2 INT, @ColName2 SYSNAME, @ColType2 SYSNAME;
DECLARE @SQL2 NVARCHAR(MAX);

DECLARE col_cursor2 CURSOR FOR
SELECT ColumnNumber, ColumnName, ColumnType
FROM @Columns;

OPEN col_cursor2;
FETCH NEXT FROM col_cursor2 INTO @ColNumber2, @ColName2, @ColType2;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @ColType2 IN (
        'int','bigint','smallint','tinyint',
        'decimal','numeric','float','real',
        'money','smallmoney',
        'date','datetime','datetime2','smalldatetime','time','datetimeoffset'
    )
    BEGIN
        SET @SQL2 = '
            UPDATE #ColumnProfile
            SET MinValue = (SELECT CONVERT(NVARCHAR(MAX), MIN(' + QUOTENAME(@ColName2) + ')) 
                            FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + '),
                MaxValue = (SELECT CONVERT(NVARCHAR(MAX), MAX(' + QUOTENAME(@ColName2) + ')) 
                            FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + ')
            WHERE ColumnNumber = ' + CAST(@ColNumber2 AS NVARCHAR(10)) + ';';
    END
    ELSE IF @ColType2 = 'bit'
    BEGIN
        SET @SQL2 = '
            UPDATE #ColumnProfile
            SET MinValue = (SELECT CONVERT(NVARCHAR(MAX), MIN(CAST(' + QUOTENAME(@ColName2) + ' AS INT))) 
                            FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + '),
                MaxValue = (SELECT CONVERT(NVARCHAR(MAX), MAX(CAST(' + QUOTENAME(@ColName2) + ' AS INT))) 
                            FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + ')
            WHERE ColumnNumber = ' + CAST(@ColNumber2 AS NVARCHAR(10)) + ';';
    END
    ELSE IF @ColType2 IN ('char','nchar','varchar','nvarchar','text','ntext')
    BEGIN
        SET @SQL2 = '
            UPDATE #ColumnProfile
            SET MinValue = (SELECT CONVERT(NVARCHAR(MAX), MIN(' + QUOTENAME(@ColName2) + ')) 
                            FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + '),
                MaxValue = (SELECT CONVERT(NVARCHAR(MAX), MAX(' + QUOTENAME(@ColName2) + ')) 
                            FROM ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + ')
            WHERE ColumnNumber = ' + CAST(@ColNumber2 AS NVARCHAR(10)) + ';';
    END
    ELSE
    BEGIN
        SET @SQL2 = NULL; -- skip unsupported types
    END

    IF @SQL2 IS NOT NULL
        EXEC (@SQL2);

    FETCH NEXT FROM col_cursor2 INTO @ColNumber2, @ColName2, @ColType2;
END;

CLOSE col_cursor2;
DEALLOCATE col_cursor2;


        SELECT
        *
    FROM #ColumnProfile;

END;
GO
