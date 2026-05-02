create PROCEDURE Utility.MRG_processSCD1
    @MergeConfigurationName     varchar(255)
    , @DebugMode                bit             = 0
AS
BEGIN
    SET NOCOUNT ON;

    /* ----------------------------------------------------------------
       Look up configuration
    ---------------------------------------------------------------- */
    DECLARE
        @QualifiedSourceName            varchar(500)
        , @QualifiedTargetName          varchar(500)
        , @MergeOnColumns               varchar(max)
        , @IgnoreColumns                varchar(max)
        , @DeleteIfNotMatchedBySource   bit
        , @IgnoreIdentityColumns        bit
        , @WH_CreateDateColumnName      varchar(255)
        , @WH_ModifiedDateColumnName    varchar(255)
        , @WH_UTCOffset                 smallint;

    SELECT
        @QualifiedSourceName            = cfg.QualifiedSourceName
        , @QualifiedTargetName          = cfg.QualifiedTargetName
        , @MergeOnColumns               = cfg.MergeOnColumns
        , @IgnoreColumns                = cfg.IgnoreColumns
        , @DeleteIfNotMatchedBySource   = cfg.DeleteIfNotMatchedBySource
        , @IgnoreIdentityColumns        = cfg.IgnoreIdentityColumns
        , @WH_CreateDateColumnName      = cfg.WH_CreateDateColumnName
        , @WH_ModifiedDateColumnName    = cfg.WH_ModifiedDateColumnName
        , @WH_UTCOffset                 = ISNULL(cfg.WH_UTCOffset, 0)
    FROM Utility.MRG_DynamicMergeConfiguration cfg
    WHERE cfg.MergeConfigurationName = @MergeConfigurationName;

    /* ----------------------------------------------------------------
       Validate config was found
    ---------------------------------------------------------------- */
    IF @QualifiedSourceName IS NULL
    BEGIN
        RAISERROR('Merge configuration [%s] was not found.', 16, 1, @MergeConfigurationName);
        RETURN;
    END;

    /* ----------------------------------------------------------------
       Parse qualified names into parts
    ---------------------------------------------------------------- */
    DECLARE
        @SourceDB           varchar(255)    = PARSENAME(@QualifiedSourceName, 3)
        , @SourceSchema     varchar(255)    = PARSENAME(@QualifiedSourceName, 2)
        , @SourceTable      varchar(255)    = PARSENAME(@QualifiedSourceName, 1)
        , @TargetDB         varchar(255)    = PARSENAME(@QualifiedTargetName, 3)
        , @TargetSchema     varchar(255)    = PARSENAME(@QualifiedTargetName, 2)
        , @TargetTable      varchar(255)    = PARSENAME(@QualifiedTargetName, 1);

    /* ----------------------------------------------------------------
       Build the timestamp expression used in dynamic SQL.
       Evaluated at row-write time rather than procedure start time.
    ---------------------------------------------------------------- */
    DECLARE @NowExpression nvarchar(100) =
        'DATEADD(MINUTE, ' + CAST(@WH_UTCOffset AS varchar(10)) + ', GETUTCDATE())';

    /* ----------------------------------------------------------------
       Build excluded columns list
       Excludes: MergeOnColumns, IgnoreColumns, WH meta columns
    ---------------------------------------------------------------- */
    DECLARE @ExcludedColumns TABLE (ColumnName varchar(255));

    /* Add MergeOnColumns */
    INSERT INTO @ExcludedColumns
    SELECT LOWER(TRIM(CAST(value AS varchar(255))))
    FROM STRING_SPLIT(@MergeOnColumns, ',')
    WHERE TRIM(CAST(value AS varchar(255))) <> '';

    /* Add IgnoreColumns */
    IF @IgnoreColumns IS NOT NULL
        INSERT INTO @ExcludedColumns
        SELECT LOWER(TRIM(CAST(value AS varchar(255))))
        FROM STRING_SPLIT(@IgnoreColumns, ',')
        WHERE TRIM(CAST(value AS varchar(255))) <> '';

    /* Add WH meta columns */
    INSERT INTO @ExcludedColumns VALUES
        (LOWER(@WH_CreateDateColumnName))
        , (LOWER(@WH_ModifiedDateColumnName));

    /* ----------------------------------------------------------------
       Discover shared columns between source and target.
       Uses sys.columns for reliable cross-database identity detection.
    ---------------------------------------------------------------- */
    IF OBJECT_ID('tempdb..#DiscoveredColumns') IS NOT NULL
        DROP TABLE #DiscoveredColumns;

    CREATE TABLE #DiscoveredColumns
    (
        ColumnName      varchar(255)
        , IsIdentity    bit
    );

    DECLARE @SQL nvarchar(max) = N'';

    SET @SQL = @SQL + N'INSERT INTO #DiscoveredColumns (ColumnName, IsIdentity)';
    SET @SQL = @SQL + N' SELECT src.COLUMN_NAME, ISNULL(sc.is_identity, 0)';
    SET @SQL = @SQL + N' FROM [' + @SourceDB + '].INFORMATION_SCHEMA.COLUMNS src';
    SET @SQL = @SQL + N' INNER JOIN [' + @TargetDB + '].INFORMATION_SCHEMA.COLUMNS tgt';
    SET @SQL = @SQL + N'     ON LOWER(tgt.TABLE_SCHEMA) = LOWER(''' + @TargetSchema + ''')';
    SET @SQL = @SQL + N'    AND LOWER(tgt.TABLE_NAME)   = LOWER(''' + @TargetTable  + ''')';
    SET @SQL = @SQL + N'    AND LOWER(tgt.COLUMN_NAME)  = LOWER(src.COLUMN_NAME)';
    SET @SQL = @SQL + N' LEFT JOIN [' + @TargetDB + '].sys.columns sc';
    SET @SQL = @SQL + N'     ON sc.object_id = OBJECT_ID(''[' + @TargetDB + '].[' + @TargetSchema + '].[' + @TargetTable + ']'')';
    SET @SQL = @SQL + N'    AND LOWER(sc.name) = LOWER(src.COLUMN_NAME)';
    SET @SQL = @SQL + N' WHERE LOWER(src.TABLE_SCHEMA) = LOWER(''' + @SourceSchema + ''')';
    SET @SQL = @SQL + N'   AND LOWER(src.TABLE_NAME)   = LOWER(''' + @SourceTable  + ''')';

    EXEC sp_executesql @SQL;

    /* ----------------------------------------------------------------
       Build column lists from discovered columns
    ---------------------------------------------------------------- */
    DECLARE
        @UpdateColumnList   nvarchar(max)   = ''
        , @ExceptSourceList nvarchar(max)   = ''
        , @ExceptTargetList nvarchar(max)   = ''
        , @InsertColList    nvarchar(max)   = ''
        , @InsertValList    nvarchar(max)   = ''
        , @MergeOnCondition nvarchar(max)   = ''
        , @ColName          nvarchar(255);

    DECLARE col_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT cast(QUOTENAME(ColumnName) as nvarchar(255))
        FROM #DiscoveredColumns
        WHERE LOWER(ColumnName) NOT IN (SELECT ColumnName FROM @ExcludedColumns)
          AND (@IgnoreIdentityColumns = 0 OR IsIdentity = 0);

    OPEN col_cursor;
    FETCH NEXT FROM col_cursor INTO @ColName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @UpdateColumnList   = @UpdateColumnList  + '        tgt.' + @ColName + ' = src.' + @ColName + CHAR(13) + CHAR(10) + '        , ';
        SET @ExceptSourceList   = @ExceptSourceList  + '        src.' + @ColName + CHAR(13) + CHAR(10) + '        , ';
        SET @ExceptTargetList   = @ExceptTargetList  + '        tgt.' + @ColName + CHAR(13) + CHAR(10) + '        , ';
        SET @InsertColList      = @InsertColList     + '        ' + @ColName + CHAR(13) + CHAR(10) + '        , ';
        SET @InsertValList      = @InsertValList     + '        src.' + @ColName + CHAR(13) + CHAR(10) + '        , ';

        FETCH NEXT FROM col_cursor INTO @ColName;
    END;

    CLOSE col_cursor;
    DEALLOCATE col_cursor;

    DROP TABLE #DiscoveredColumns;

    /* Remove trailing commas */
    IF LEN(@UpdateColumnList) > 0
        SET @UpdateColumnList = LEFT(@UpdateColumnList, LEN(@UpdateColumnList) - 3);
    IF LEN(@ExceptSourceList) > 0
        SET @ExceptSourceList = LEFT(@ExceptSourceList, LEN(@ExceptSourceList) - 3);
    IF LEN(@ExceptTargetList) > 0
        SET @ExceptTargetList = LEFT(@ExceptTargetList, LEN(@ExceptTargetList) - 3);
    IF LEN(@InsertColList) > 0
        SET @InsertColList = LEFT(@InsertColList, LEN(@InsertColList) - 3);
    IF LEN(@InsertValList) > 0
        SET @InsertValList = LEFT(@InsertValList, LEN(@InsertValList) - 3);

    /* ----------------------------------------------------------------
       Build MergeOn join condition
    ---------------------------------------------------------------- */
    DECLARE @MergeOnCol nvarchar(255);

    DECLARE mergeon_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT cast(QUOTENAME(TRIM(CAST(value AS varchar(255)))) as nvarchar(255))
        FROM STRING_SPLIT(@MergeOnColumns, ',')
        WHERE TRIM(CAST(value AS varchar(255))) <> '';

    OPEN mergeon_cursor;
    FETCH NEXT FROM mergeon_cursor INTO @MergeOnCol;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @MergeOnCondition <> ''
            SET @MergeOnCondition = @MergeOnCondition + CHAR(13) + CHAR(10) + '      AND ';
        SET @MergeOnCondition = @MergeOnCondition + 'tgt.' + @MergeOnCol + ' = src.' + @MergeOnCol;

        /* Add MergeOn columns to INSERT lists */
        SET @InsertColList = @InsertColList + CASE WHEN @InsertColList <> '' THEN CHAR(13) + CHAR(10) + '        , ' ELSE '        ' END + @MergeOnCol;
        SET @InsertValList = @InsertValList + CASE WHEN @InsertValList <> '' THEN CHAR(13) + CHAR(10) + '        , ' ELSE '        ' END + 'src.' + @MergeOnCol;

        FETCH NEXT FROM mergeon_cursor INTO @MergeOnCol;
    END;

    CLOSE mergeon_cursor;
    DEALLOCATE mergeon_cursor;

    /* ----------------------------------------------------------------
       Add WH meta columns to INSERT lists
    ---------------------------------------------------------------- */
    SET @InsertColList = @InsertColList
        + CHAR(13) + CHAR(10) + '        , ' + cast(QUOTENAME(@WH_CreateDateColumnName) as varchar(max))
        + CHAR(13) + CHAR(10) + '        , ' + cast(QUOTENAME(@WH_ModifiedDateColumnName) as varchar(max));

    SET @InsertValList = @InsertValList
        + CHAR(13) + CHAR(10) + '        , ' + @NowExpression
        + CHAR(13) + CHAR(10) + '        , ' + @NowExpression;

    /* ----------------------------------------------------------------
       Build final MERGE statement
    ---------------------------------------------------------------- */
    DECLARE @MergeSQL nvarchar(max) = N'';

    SET @MergeSQL = @MergeSQL + N'MERGE ' + QUOTENAME(@TargetDB) + '.' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@TargetTable) + ' AS tgt
USING ' + QUOTENAME(@SourceDB) + '.' + QUOTENAME(@SourceSchema) + '.' + QUOTENAME(@SourceTable) + ' AS src
    ON (
      ' + @MergeOnCondition + '
    )

/* ----------------------------------------------------------------
   Matched and data has changed - UPDATE
---------------------------------------------------------------- */
WHEN MATCHED
    AND EXISTS (
        SELECT
' + @ExceptSourceList + '
        EXCEPT
        SELECT
' + @ExceptTargetList + '
    )
THEN UPDATE SET
' + @UpdateColumnList + '
        , tgt.' + QUOTENAME(@WH_ModifiedDateColumnName) + ' = ' + @NowExpression + '

/* ----------------------------------------------------------------
   Not matched by target - INSERT
---------------------------------------------------------------- */
WHEN NOT MATCHED BY TARGET
THEN INSERT
    (
' + @InsertColList + '
    )
    VALUES
    (
' + @InsertValList + '
    )';

    /* Not matched by source - hard delete */
    IF @DeleteIfNotMatchedBySource = 1
        SET @MergeSQL = @MergeSQL + N'

/* ----------------------------------------------------------------
   Not matched by source - hard DELETE
---------------------------------------------------------------- */
WHEN NOT MATCHED BY SOURCE
THEN DELETE';

    SET @MergeSQL = @MergeSQL + N'
;';

    /* ----------------------------------------------------------------
       Debug or Execute
    ---------------------------------------------------------------- */
    IF @DebugMode = 1
        SELECT @MergeSQL AS GeneratedSQL;
    ELSE
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;
                EXEC sp_executesql @MergeSQL;
            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
            THROW;
        END CATCH;
    END;

END;