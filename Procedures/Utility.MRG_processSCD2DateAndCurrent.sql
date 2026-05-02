IF OBJECT_ID('Utility.MRG_processSCD2DateAndCurrent', 'P') IS NOT NULL
    DROP PROCEDURE Utility.MRG_processSCD2DateAndCurrent;
GO

/* =====================================================================
   Utility.MRG_processSCD2DateAndCurrent
   -----------------------------------------------------------------------
   Performs a dynamic SCD Type 2 merge using date ranges and an
   IsCurrent flag.

   Each time a row changes, the active row is closed off and a new row
   is inserted. Full history is retained.

   Because a standard MERGE cannot close off an existing row and insert
   a new one for the same logical key in a single pass, this procedure
   uses three statements run inside a single transaction:

       1a. UPDATE to close off active rows where source data has changed.
           Sets WH_RowExpirationDate = now, WH_IsCurrent = 0.
       1b. UPDATE to soft-delete active rows no longer in source when DeleteIfNotMatchBySource = 1.
           if DeleteIfNotMatchBySource = 0 then the record does not need to be in source 
        2. INSERT new rows for changed and new records.
           Sets WH_RowEffectiveDate = now, WH_RowExpirationDate =
           WH_RowExpirationDateValue, WH_IsCurrent = 1, WH_IsDeleted = 0.

    Step 2 inserts a new row for every source record that does not have
       an active row in target (WH_IsCurrent = 1). This naturally covers
       three cases:
           - Changed records: their active row was just closed in step 1a.
           - New records: they have no rows in target at all.
           - Soft-deleted records: their active row still exists, so no
             new row is inserted.

   Parameters:
       @MergeConfigurationName     - The name of the merge configuration
       @DebugMode                  - 1 = print dynamic SQL, 0 = execute

   WH columns used:
       WH_CreateDateColumnName         - Set on INSERT of every new row
       WH_ModifiedDateColumnName       - Set on INSERT and UPDATE
       WH_RowEffectiveDateColumnName   - Set to now on INSERT
       WH_RowExpirationDateColumnName  - Set to WH_RowExpirationDateValue
                                         on INSERT, set to now on close-off
       WH_IsCurrentColumnName          - 1 on active row, 0 on closed rows
       WH_isDeletedColumnName          - Set to 1 when not matched by source
                                         (only when DeleteIfNotMatchedBySource = 1)
   ===================================================================== */
CREATE PROCEDURE Utility.MRG_processSCD2DateAndCurrent
    @MergeConfigurationName     varchar(255)
    , @DebugMode                bit             = 0
AS
BEGIN
    SET NOCOUNT ON;

    /* ----------------------------------------------------------------
       Look up configuration
    ---------------------------------------------------------------- */
    DECLARE
        @QualifiedSourceName                varchar(500)
        , @QualifiedTargetName              varchar(500)
        , @MergeOnColumns                   varchar(max)
        , @IgnoreColumns                    varchar(max)
        , @DeleteIfNotMatchedBySource       bit
        , @IgnoreIdentityColumns            bit
        , @WH_CreateDateColumnName          varchar(255)
        , @WH_ModifiedDateColumnName        varchar(255)
        , @WH_RowEffectiveDateColumnName    varchar(255)
        , @WH_RowExpirationDateColumnName   varchar(255)
        , @WH_RowExpirationDateValue        datetime2
        , @WH_IsCurrentColumnName           varchar(255)
        , @WH_isDeletedColumnName           varchar(255)
        , @WH_UTCOffset                     smallint;

    SELECT
        @QualifiedSourceName                = cfg.QualifiedSourceName
        , @QualifiedTargetName              = cfg.QualifiedTargetName
        , @MergeOnColumns                   = cfg.MergeOnColumns
        , @IgnoreColumns                    = cfg.IgnoreColumns
        , @DeleteIfNotMatchedBySource       = cfg.DeleteIfNotMatchedBySource
        , @IgnoreIdentityColumns            = cfg.IgnoreIdentityColumns
        , @WH_CreateDateColumnName          = cfg.WH_CreateDateColumnName
        , @WH_ModifiedDateColumnName        = cfg.WH_ModifiedDateColumnName
        , @WH_RowEffectiveDateColumnName    = cfg.WH_RowEffectiveDateColumnName
        , @WH_RowExpirationDateColumnName   = cfg.WH_RowExpirationDateColumnName
        , @WH_RowExpirationDateValue        = cfg.WH_RowExpirationDateValue
        , @WH_IsCurrentColumnName           = cfg.WH_IsCurrentColumnName
        , @WH_isDeletedColumnName           = cfg.WH_isDeletedColumnName
        , @WH_UTCOffset                     = ISNULL(cfg.WH_UTCOffset, 0)
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
        @SourceDB       varchar(255)    = PARSENAME(@QualifiedSourceName, 3)
        , @SourceSchema varchar(255)    = PARSENAME(@QualifiedSourceName, 2)
        , @SourceTable  varchar(255)    = PARSENAME(@QualifiedSourceName, 1)
        , @TargetDB     varchar(255)    = PARSENAME(@QualifiedTargetName, 3)
        , @TargetSchema varchar(255)    = PARSENAME(@QualifiedTargetName, 2)
        , @TargetTable  varchar(255)    = PARSENAME(@QualifiedTargetName, 1);

    /* ----------------------------------------------------------------
       Build the timestamp expression used in dynamic SQL.
       Evaluated at row-write time rather than procedure start time.
    ---------------------------------------------------------------- */
    DECLARE @NowExpression nvarchar(100) =
        'DATEADD(MINUTE, ' + CAST(@WH_UTCOffset AS varchar(10)) + ', GETUTCDATE())';

    /* ----------------------------------------------------------------
       Build the expiration date value expression.
       Cast to varchar so it can be embedded as a literal in dynamic SQL.
    ---------------------------------------------------------------- */
    DECLARE @ExpirationDateValue nvarchar(50) =
        '''' + CONVERT(varchar(50), @WH_RowExpirationDateValue, 120) + '''';

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
        , (LOWER(@WH_ModifiedDateColumnName))
        , (LOWER(@WH_RowEffectiveDateColumnName))
        , (LOWER(@WH_RowExpirationDateColumnName))
        , (LOWER(@WH_IsCurrentColumnName))
        , (LOWER(@WH_isDeletedColumnName));

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
        @ExceptSourceList   nvarchar(max)   = ''
        , @ExceptTargetList nvarchar(max)   = ''
        , @InsertColList    nvarchar(max)   = ''
        , @InsertValList    nvarchar(max)   = ''
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
        SET @ExceptSourceList   = @ExceptSourceList + '        src.' + @ColName + CHAR(13) + CHAR(10) + '        , ';
        SET @ExceptTargetList   = @ExceptTargetList + '        tgt.' + @ColName + CHAR(13) + CHAR(10) + '        , ';
        SET @InsertColList      = @InsertColList    + '        ' + @ColName + CHAR(13) + CHAR(10) + '        , ';
        SET @InsertValList      = @InsertValList    + '        src.' + @ColName + CHAR(13) + CHAR(10) + '        , ';

        FETCH NEXT FROM col_cursor INTO @ColName;
    END;

    CLOSE col_cursor;
    DEALLOCATE col_cursor;

    DROP TABLE #DiscoveredColumns;

    /* Remove trailing commas */
    IF LEN(@ExceptSourceList) > 0
        SET @ExceptSourceList = LEFT(@ExceptSourceList, LEN(@ExceptSourceList) - 3);
    IF LEN(@ExceptTargetList) > 0
        SET @ExceptTargetList = LEFT(@ExceptTargetList, LEN(@ExceptTargetList) - 3);
    IF LEN(@InsertColList) > 0
        SET @InsertColList = LEFT(@InsertColList, LEN(@InsertColList) - 3);
    IF LEN(@InsertValList) > 0
        SET @InsertValList = LEFT(@InsertValList, LEN(@InsertValList) - 3);

    /* ----------------------------------------------------------------
       Build join condition strings for all alias combinations needed
       across the three dynamic statements.

       @JoinCondition_Inner  - tgt_inner / src_inner  (close-off subquery)
       @JoinCondition_Outer  - tgt       / changed    (close-off outer join)
       @MergeOnSelectList    - tgt_inner columns      (close-off subquery SELECT)
       @MergeOnJoinCheck     - tgt_check / src         (IsCurrent guard)
       @MergeOnJoinSoftDel   - tgt       / src_del     (soft-delete NOT EXISTS)
    ---------------------------------------------------------------- */
    DECLARE
        @JoinCondition_Inner    nvarchar(max)   = ''
        , @JoinCondition_Outer  nvarchar(max)   = ''
        , @MergeOnSelectList    nvarchar(max)   = ''
        , @MergeOnJoinCheck     nvarchar(max)   = ''
        , @MergeOnJoinSoftDel   nvarchar(max)   = ''
        , @MergeOnCol           nvarchar(255);

    DECLARE mergeon_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT cast(QUOTENAME(TRIM(CAST(value AS varchar(255)))) as nvarchar(255))
        FROM STRING_SPLIT(@MergeOnColumns, ',')
        WHERE TRIM(CAST(value AS varchar(255))) <> '';

    OPEN mergeon_cursor;
    FETCH NEXT FROM mergeon_cursor INTO @MergeOnCol;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        /* Prepend AND separator for all but the first column */
        IF @JoinCondition_Inner <> ''
        BEGIN
            SET @JoinCondition_Inner  = @JoinCondition_Inner  + CHAR(13) + CHAR(10) + '          AND ';
            SET @JoinCondition_Outer  = @JoinCondition_Outer  + CHAR(13) + CHAR(10) + '      AND ';
            SET @MergeOnSelectList    = @MergeOnSelectList    + CHAR(13) + CHAR(10) + '        , ';
            SET @MergeOnJoinCheck     = @MergeOnJoinCheck     + CHAR(13) + CHAR(10) + '      AND ';
            SET @MergeOnJoinSoftDel   = @MergeOnJoinSoftDel   + CHAR(13) + CHAR(10) + '        AND ';
        END;

        SET @JoinCondition_Inner  = @JoinCondition_Inner  + 'tgt_inner.' + @MergeOnCol + ' = src_inner.' + @MergeOnCol;
        SET @JoinCondition_Outer  = @JoinCondition_Outer  + 'tgt.'       + @MergeOnCol + ' = changed.'   + @MergeOnCol;
        SET @MergeOnSelectList    = @MergeOnSelectList    + 'tgt_inner.' + @MergeOnCol;
        SET @MergeOnJoinCheck     = @MergeOnJoinCheck     + 'tgt_check.' + @MergeOnCol + ' = src.'       + @MergeOnCol;
        SET @MergeOnJoinSoftDel   = @MergeOnJoinSoftDel   + 'tgt.'       + @MergeOnCol + ' = src_del.'   + @MergeOnCol;

        /* Add MergeOn columns to INSERT lists */
        SET @InsertColList = @InsertColList + CHAR(13) + CHAR(10) + '        , ' + @MergeOnCol;
        SET @InsertValList = @InsertValList + CHAR(13) + CHAR(10) + '        , src.' + @MergeOnCol;

        FETCH NEXT FROM mergeon_cursor INTO @MergeOnCol;
    END;

    CLOSE mergeon_cursor;
    DEALLOCATE mergeon_cursor;

    /* ----------------------------------------------------------------
       Append WH meta columns to INSERT lists
    ---------------------------------------------------------------- */
    SET @InsertColList = @InsertColList + CHAR(13) + CHAR(10) + '        , ' + QUOTENAME(@WH_CreateDateColumnName);
    SET @InsertColList = @InsertColList + CHAR(13) + CHAR(10) + '        , ' + QUOTENAME(@WH_ModifiedDateColumnName);
    SET @InsertColList = @InsertColList + CHAR(13) + CHAR(10) + '        , ' + QUOTENAME(@WH_RowEffectiveDateColumnName);
    SET @InsertColList = @InsertColList + CHAR(13) + CHAR(10) + '        , ' + QUOTENAME(@WH_RowExpirationDateColumnName);
    SET @InsertColList = @InsertColList + CHAR(13) + CHAR(10) + '        , ' + QUOTENAME(@WH_IsCurrentColumnName);
    SET @InsertColList = @InsertColList + CHAR(13) + CHAR(10) + '        , ' + QUOTENAME(@WH_isDeletedColumnName);

    SET @InsertValList = @InsertValList + CHAR(13) + CHAR(10) + '        , ' + @NowExpression;
    SET @InsertValList = @InsertValList + CHAR(13) + CHAR(10) + '        , ' + @NowExpression;
    SET @InsertValList = @InsertValList + CHAR(13) + CHAR(10) + '        , ' + @NowExpression;
    SET @InsertValList = @InsertValList + CHAR(13) + CHAR(10) + '        , ' + @ExpirationDateValue;
    SET @InsertValList = @InsertValList + CHAR(13) + CHAR(10) + '        , 1';
    SET @InsertValList = @InsertValList + CHAR(13) + CHAR(10) + '        , 0';

    /* ================================================================
       Build Statement 1a - close off active rows where data has changed.

       Joins the target to a subquery that finds keys whose active row
       differs from source using EXCEPT, then sets WH_RowExpirationDate
       = now and WH_IsCurrent = 0 on those active rows.
    ================================================================ */
    DECLARE @CloseOffSQL nvarchar(max) = N'';

    SET @CloseOffSQL = @CloseOffSQL + '/* ----------------------------------------------------------------' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '   Step 1a: Close off active rows where source data has changed' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '---------------------------------------------------------------- */' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + 'UPDATE tgt' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + 'SET' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '    tgt.' + QUOTENAME(@WH_RowExpirationDateColumnName) + ' = ' + @NowExpression + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '    , tgt.' + QUOTENAME(@WH_ModifiedDateColumnName) + ' = ' + @NowExpression + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '    , tgt.' + QUOTENAME(@WH_IsCurrentColumnName) + ' = 0' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + 'FROM ' + QUOTENAME(@TargetDB) + '.' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@TargetTable) + ' tgt' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + 'INNER JOIN' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '(' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '    SELECT' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '        ' + @MergeOnSelectList + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '    FROM ' + QUOTENAME(@TargetDB) + '.' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@TargetTable) + ' tgt_inner' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '    INNER JOIN ' + QUOTENAME(@SourceDB) + '.' + QUOTENAME(@SourceSchema) + '.' + QUOTENAME(@SourceTable) + ' src_inner' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '        ON ' + @JoinCondition_Inner + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '    WHERE tgt_inner.' + QUOTENAME(@WH_IsCurrentColumnName) + ' = 1' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '      AND EXISTS' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '      (' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '            SELECT' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + @ExceptTargetList + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '            EXCEPT' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '            SELECT' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + @ExceptSourceList + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '      )' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + ') AS changed' + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + '    ON ' + @JoinCondition_Outer + CHAR(13) + CHAR(10);
    SET @CloseOffSQL = @CloseOffSQL + 'WHERE tgt.' + QUOTENAME(@WH_IsCurrentColumnName) + ' = 1;';

    /* ================================================================
       Build Statement 1b - soft-delete rows absent from source.
       Only built when DeleteIfNotMatchedBySource = 1.

       WH_IsCurrent remains 1 - the deleted state IS the current state.
       The WH_IsDeleted = 0 guard makes repeat runs idempotent.
    ================================================================ */
    DECLARE @SoftDeleteSQL nvarchar(max) = N'';

    IF @DeleteIfNotMatchedBySource = 1
    BEGIN
        SET @SoftDeleteSQL = @SoftDeleteSQL + '/* ----------------------------------------------------------------' + CHAR(13) + CHAR(10);
        SET @SoftDeleteSQL = @SoftDeleteSQL + '   Step 1b: Soft-delete active rows no longer present in source' + CHAR(13) + CHAR(10);
        SET @SoftDeleteSQL = @SoftDeleteSQL + '---------------------------------------------------------------- */' + CHAR(13) + CHAR(10);
        SET @SoftDeleteSQL = @SoftDeleteSQL + 'UPDATE tgt' + CHAR(13) + CHAR(10);
        SET @SoftDeleteSQL = @SoftDeleteSQL + 'SET' + CHAR(13) + CHAR(10);
        SET @SoftDeleteSQL = @SoftDeleteSQL + '    tgt.' + QUOTENAME(@WH_isDeletedColumnName) + ' = 1' + CHAR(13) + CHAR(10);
        SET @SoftDeleteSQL = @SoftDeleteSQL + '    , tgt.' + QUOTENAME(@WH_ModifiedDateColumnName) + ' = ' + @NowExpression + CHAR(13) + CHAR(10);
        SET @SoftDeleteSQL = @SoftDeleteSQL + 'FROM ' + QUOTENAME(@TargetDB) + '.' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@TargetTable) + ' tgt' + CHAR(13) + CHAR(10);
        SET @SoftDeleteSQL = @SoftDeleteSQL + 'WHERE tgt.' + QUOTENAME(@WH_IsCurrentColumnName) + ' = 1' + CHAR(13) + CHAR(10);
        SET @SoftDeleteSQL = @SoftDeleteSQL + '  AND tgt.' + QUOTENAME(@WH_isDeletedColumnName) + ' = 0' + CHAR(13) + CHAR(10);
        SET @SoftDeleteSQL = @SoftDeleteSQL + '  AND NOT EXISTS' + CHAR(13) + CHAR(10);
        SET @SoftDeleteSQL = @SoftDeleteSQL + '  (' + CHAR(13) + CHAR(10);
        SET @SoftDeleteSQL = @SoftDeleteSQL + '        SELECT 1' + CHAR(13) + CHAR(10);
        SET @SoftDeleteSQL = @SoftDeleteSQL + '        FROM ' + QUOTENAME(@SourceDB) + '.' + QUOTENAME(@SourceSchema) + '.' + QUOTENAME(@SourceTable) + ' src_del' + CHAR(13) + CHAR(10);
        SET @SoftDeleteSQL = @SoftDeleteSQL + '        WHERE ' + @MergeOnJoinSoftDel + CHAR(13) + CHAR(10);
        SET @SoftDeleteSQL = @SoftDeleteSQL + '  );';
    END;

    /* ================================================================
       Build Statement 2 - insert new rows for changed and new records.
    ================================================================ */
    DECLARE @InsertSQL nvarchar(max) = N'';

    SET @InsertSQL = @InsertSQL + '/* ----------------------------------------------------------------' + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + '   Step 2: Insert new rows for changed and new records' + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + '---------------------------------------------------------------- */' + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + 'INSERT INTO ' + QUOTENAME(@TargetDB) + '.' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@TargetTable) + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + '(' + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + @InsertColList + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + ')' + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + 'SELECT' + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + @InsertValList + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + 'FROM ' + QUOTENAME(@SourceDB) + '.' + QUOTENAME(@SourceSchema) + '.' + QUOTENAME(@SourceTable) + ' src' + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + '/* Only insert where the active row no longer exists.' + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + '   Covers changed records (closed in step 1a) and new records.' + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + '   Soft-deleted rows are correctly suppressed. */' + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + 'WHERE NOT EXISTS' + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + '(' + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + '    SELECT 1' + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + '    FROM ' + QUOTENAME(@TargetDB) + '.' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@TargetTable) + ' tgt_check' + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + '    WHERE ' + @MergeOnJoinCheck + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + '      AND tgt_check.' + QUOTENAME(@WH_IsCurrentColumnName) + ' = 1' + CHAR(13) + CHAR(10);
    SET @InsertSQL = @InsertSQL + ');';

    /* ----------------------------------------------------------------
       Debug or Execute
    ---------------------------------------------------------------- */
    IF @DebugMode = 1
    BEGIN
        SELECT @CloseOffSQL     AS [Step1a_CloseOffChangedRows];
        SELECT @SoftDeleteSQL   AS [Step1b_SoftDeleteAbsentRows];
        SELECT @InsertSQL       AS [Step2_InsertNewRows];
    END
    ELSE
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;
                EXEC sp_executesql @CloseOffSQL;

                IF @DeleteIfNotMatchedBySource = 1
                    EXEC sp_executesql @SoftDeleteSQL;

                EXEC sp_executesql @InsertSQL;
            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
            THROW;
        END CATCH;
    END;

END;