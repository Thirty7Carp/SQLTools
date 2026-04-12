IF OBJECT_ID('Utility.MRG_processSCD2Version', 'P') IS NOT NULL
    DROP PROCEDURE Utility.MRG_processSCD2Version;
GO

/* =====================================================================
   Utility.MRG_processSCD2Version
   -----------------------------------------------------------------------
   Performs a dynamic SCD Type 2 merge using version numbers.

   Each time a row changes, the active row is retired (WH_IsCurrent = 0)
   and a new row is inserted with an incremented version number and
   WH_IsCurrent = 1. Full history is retained.

   WH columns used:
       WH_CreateDateColumnName     - Set on INSERT of every new row
       WH_VersionColumnName        - 1 for new records, MAX + 1 for updates
       WH_IsCurrentColumnName      - 1 on active row, 0 on retired rows
       WH_isDeletedColumnName      - Set to 1 when not matched by source
                                     (only when DeleteIfNotMatchedBySource = 1)
   ===================================================================== */
CREATE PROCEDURE Utility.MRG_processSCD2Version
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
        , @WH_VersionColumnName         varchar(255)
        , @WH_IsCurrentColumnName       varchar(255)
        , @WH_isDeletedColumnName       varchar(255)
        , @WH_UTCOffset                 smallint;

    SELECT
        @QualifiedSourceName            = cfg.QualifiedSourceName
        , @QualifiedTargetName          = cfg.QualifiedTargetName
        , @MergeOnColumns               = cfg.MergeOnColumns
        , @IgnoreColumns                = cfg.IgnoreColumns
        , @DeleteIfNotMatchedBySource   = cfg.DeleteIfNotMatchedBySource
        , @IgnoreIdentityColumns        = cfg.IgnoreIdentityColumns
        , @WH_CreateDateColumnName      = cfg.WH_CreateDateColumnName
        , @WH_VersionColumnName         = cfg.WH_VersionColumnName
        , @WH_IsCurrentColumnName       = cfg.WH_IsCurrentColumnName
        , @WH_isDeletedColumnName       = cfg.WH_isDeletedColumnName
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
    DECLARE @NowExpression varchar(100) =
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
        , (LOWER(@WH_VersionColumnName))
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

    DECLARE @SQL nvarchar(max);

    SET @SQL = N'
        INSERT INTO #DiscoveredColumns (ColumnName, IsIdentity)
        SELECT
            src.COLUMN_NAME
            , ISNULL(sc.is_identity, 0)
        FROM [' + @SourceDB + '].INFORMATION_SCHEMA.COLUMNS src
        INNER JOIN [' + @TargetDB + '].INFORMATION_SCHEMA.COLUMNS tgt
            ON LOWER(tgt.TABLE_SCHEMA) = LOWER(''' + @TargetSchema + ''')
            AND LOWER(tgt.TABLE_NAME)  = LOWER(''' + @TargetTable  + ''')
            AND LOWER(tgt.COLUMN_NAME) = LOWER(src.COLUMN_NAME)
        LEFT JOIN [' + @TargetDB + '].sys.columns sc
            ON sc.object_id = OBJECT_ID(''[' + @TargetDB + '].[' + @TargetSchema + '].[' + @TargetTable + ']'')
            AND LOWER(sc.name) = LOWER(src.COLUMN_NAME)
        WHERE LOWER(src.TABLE_SCHEMA) = LOWER(''' + @SourceSchema + ''')
          AND LOWER(src.TABLE_NAME)   = LOWER(''' + @SourceTable  + ''')';

    EXEC sp_executesql @SQL;

    /* ----------------------------------------------------------------
       Build column lists from discovered columns
    ---------------------------------------------------------------- */
    DECLARE
        @ExceptSourceList   varchar(max)    = ''
        , @ExceptTargetList varchar(max)    = ''
        , @InsertColList    varchar(max)    = ''
        , @InsertValList    varchar(max)    = ''
        , @ColName          varchar(255);

    DECLARE col_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT QUOTENAME(ColumnName)
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
       Build MergeOn join condition
    ---------------------------------------------------------------- */
    DECLARE
        @MergeOnCondition   varchar(max)    = ''
        , @MergeOnCol       varchar(255);

    DECLARE mergeon_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT QUOTENAME(TRIM(CAST(value AS varchar(255))))
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
       Add WH meta columns to INSERT list
    ---------------------------------------------------------------- */
    SET @InsertColList = @InsertColList
        + CHAR(13) + CHAR(10) + '        , ' + QUOTENAME(@WH_CreateDateColumnName)
        + CHAR(13) + CHAR(10) + '        , ' + QUOTENAME(@WH_VersionColumnName)
        + CHAR(13) + CHAR(10) + '        , ' + QUOTENAME(@WH_IsCurrentColumnName)
        + CHAR(13) + CHAR(10) + '        , ' + QUOTENAME(@WH_isDeletedColumnName);

    SET @InsertValList = @InsertValList
        + CHAR(13) + CHAR(10) + '        , ' + @NowExpression
        + CHAR(13) + CHAR(10) + '        , ' + 'src.__NewVersion'
        + CHAR(13) + CHAR(10) + '        , ' + '1'
        + CHAR(13) + CHAR(10) + '        , ' + '0';

    /* ----------------------------------------------------------------
       Fully qualified object references for dynamic SQL
    ---------------------------------------------------------------- */
    DECLARE
        @FQTarget   varchar(500) = QUOTENAME(@TargetDB) + '.' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@TargetTable)
        , @FQSource varchar(500) = QUOTENAME(@SourceDB) + '.' + QUOTENAME(@SourceSchema) + '.' + QUOTENAME(@SourceTable);

    /* ================================================================
       Statement 1 - RETIRE changed active rows and soft-delete rows
                     no longer present in the source.

       Targets only the active row (WH_IsCurrent = 1) for each key.
       Sets WH_IsCurrent = 0. When DeleteIfNotMatchedBySource = 1,
       also sets WH_IsDeleted = 1 on rows absent from source.
    ================================================================ */
    DECLARE @RetireSQL nvarchar(max) = N'
UPDATE tgt
SET
    tgt.' + QUOTENAME(@WH_IsCurrentColumnName) + ' = 0'

    /* Soft-delete flag is only set for not-matched-by-source rows.
       We determine this by outer-joining to source and checking for NULL. */
    + CHAR(13) + CHAR(10) + '    , tgt.' + QUOTENAME(@WH_isDeletedColumnName) + ' = CASE
        WHEN src_del.__IsAbsent = 1 THEN 1
        ELSE tgt.' + QUOTENAME(@WH_isDeletedColumnName) + '
    END'

    + N'
FROM ' + @FQTarget + ' tgt
/* Join to changed active rows */
INNER JOIN
(
    SELECT ' + @MergeOnCondition + N'
    /* Subquery: active rows in target where source data has changed */
    SELECT
        tgt_inner.' + QUOTENAME(@MergeOnColumns) + N'  /* placeholder - rebuilt below */
    FROM ' + @FQTarget + N' tgt_inner
    INNER JOIN ' + @FQSource + N' src_inner
        ON ' + @MergeOnCondition;

    /*
       The retire statement is complex enough that we build it cleanly
       as a fully formed string rather than concatenating fragments above.
       Reset and build properly.
    */

    /* ----------------------------------------------------------------
       Build the MergeOn join clause as a list of tgt/src column pairs
       for use inside subqueries (tgt_inner / src_inner aliases).
    ---------------------------------------------------------------- */
    DECLARE
        @JoinCondition_Inner    varchar(max)    = ''
        , @JoinCondition_Outer  varchar(max)    = ''
        , @MergeOnSelectList    varchar(max)    = ''
        , @MergeOnJoinSrc       varchar(max)    = '';

    DECLARE mergeon2_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT QUOTENAME(TRIM(CAST(value AS varchar(255))))
        FROM STRING_SPLIT(@MergeOnColumns, ',')
        WHERE TRIM(CAST(value AS varchar(255))) <> '';

    OPEN mergeon2_cursor;
    FETCH NEXT FROM mergeon2_cursor INTO @MergeOnCol;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @JoinCondition_Inner <> ''
        BEGIN
            SET @JoinCondition_Inner    = @JoinCondition_Inner  + CHAR(13) + CHAR(10) + '          AND ';
            SET @JoinCondition_Outer    = @JoinCondition_Outer  + CHAR(13) + CHAR(10) + '      AND ';
            SET @MergeOnSelectList      = @MergeOnSelectList    + CHAR(13) + CHAR(10) + '        , ';
            SET @MergeOnJoinSrc         = @MergeOnJoinSrc       + CHAR(13) + CHAR(10) + '      AND ';
        END;

        SET @JoinCondition_Inner    = @JoinCondition_Inner  + 'tgt_inner.' + @MergeOnCol + ' = src_inner.' + @MergeOnCol;
        SET @JoinCondition_Outer    = @JoinCondition_Outer  + 'tgt.' + @MergeOnCol + ' = changed.' + @MergeOnCol;
        SET @MergeOnSelectList      = @MergeOnSelectList    + 'tgt_inner.' + @MergeOnCol;
        SET @MergeOnJoinSrc         = @MergeOnJoinSrc       + 'tgt.' + @MergeOnCol + ' = src_del.' + @MergeOnCol;

        FETCH NEXT FROM mergeon2_cursor INTO @MergeOnCol;
    END;

    CLOSE mergeon2_cursor;
    DEALLOCATE mergeon2_cursor;

    /* ----------------------------------------------------------------
       Build Statement 1 - retire active rows that have changed
    ---------------------------------------------------------------- */
    SET @RetireSQL = N'
/* ----------------------------------------------------------------
   Step 1a: Retire active rows where source data has changed
---------------------------------------------------------------- */
UPDATE tgt
SET
    tgt.' + QUOTENAME(@WH_IsCurrentColumnName) + ' = 0
FROM ' + @FQTarget + ' tgt
INNER JOIN
(
    SELECT
        ' + @MergeOnSelectList + '
    FROM ' + @FQTarget + ' tgt_inner
    INNER JOIN ' + @FQSource + ' src_inner
        ON ' + @JoinCondition_Inner + '
    WHERE tgt_inner.' + QUOTENAME(@WH_IsCurrentColumnName) + ' = 1
      AND EXISTS (
            SELECT
' + @ExceptTargetList + '
            EXCEPT
            SELECT
' + @ExceptSourceList + '
        )
) AS changed
    ON ' + @JoinCondition_Outer + '
WHERE tgt.' + QUOTENAME(@WH_IsCurrentColumnName) + ' = 1;
';

    /* ----------------------------------------------------------------
       Build Statement 1b - soft-delete rows absent from source
       Only appended when DeleteIfNotMatchedBySource = 1
    ---------------------------------------------------------------- */
    DECLARE @SoftDeleteSQL nvarchar(max) = '';

    IF @DeleteIfNotMatchedBySource = 1
        SET @SoftDeleteSQL = N'
/* ----------------------------------------------------------------
   Step 1b: Soft-delete active rows no longer present in source.
   WH_IsCurrent remains 1 - this IS the current state of the row.
   WH_IsDeleted = 1 signals that the current state is a deletion.
   Step 2 will not insert a new version for these rows because
   the active row (WH_IsCurrent = 1) still exists in target.
---------------------------------------------------------------- */
UPDATE tgt
SET
    tgt.' + QUOTENAME(@WH_isDeletedColumnName) + ' = 1
FROM ' + @FQTarget + ' tgt
WHERE tgt.' + QUOTENAME(@WH_IsCurrentColumnName) + ' = 1
  AND tgt.' + QUOTENAME(@WH_isDeletedColumnName) + ' = 0
  AND NOT EXISTS (
        SELECT 1
        FROM ' + @FQSource + ' src_del
        WHERE ' + @MergeOnJoinSrc + '
    );
';

    /* ================================================================
       Statement 2 - INSERT new version rows.

       Uses a CTE to calculate MAX(version) + 1 per key from the target,
       then joins source to target to find:
           a) New records (no match in target)
           b) Changed records (previously retired in step 1a)
    ================================================================ */
    DECLARE @InsertSQL nvarchar(max) = N'
/* ----------------------------------------------------------------
   Step 2: Insert new version rows for changed and new records
---------------------------------------------------------------- */
WITH MaxVersion AS
(
    SELECT
        ' + @MergeOnSelectList + '
        , MAX(' + QUOTENAME(@WH_VersionColumnName) + ') AS __MaxVersion
    FROM ' + @FQTarget + '
    GROUP BY
        ' + @MergeOnSelectList + '
)
INSERT INTO ' + @FQTarget + '
(
' + @InsertColList + '
)
SELECT
' + @InsertValList + '
FROM ' + @FQSource + ' src
/* Derive the new version number.
   New records (no prior version) start at 1.
   Changed records increment from their current MAX. */
CROSS APPLY
(
    SELECT ISNULL(mv.__MaxVersion, 0) + 1 AS __NewVersion
    FROM (SELECT 1 AS __Dummy) AS __One
    LEFT JOIN MaxVersion mv
        ON ' + @MergeOnJoinSrc + N'
) AS src
/* Only insert where the active row no longer exists.
   This covers both changed records (retired in step 1a)
   and brand new records (never existed in target). */
WHERE NOT EXISTS
(
    SELECT 1
    FROM ' + @FQTarget + ' tgt_check
    WHERE ' + @MergeOnJoinSrc + N'
      AND tgt_check.' + QUOTENAME(@WH_IsCurrentColumnName) + ' = 1
);
';

    /* ----------------------------------------------------------------
       Fix the CROSS APPLY join - @MergeOnJoinSrc uses tgt. prefix,
       but inside the CTE join we need mv. prefix.
       Rebuild a mv-specific join string.
    ---------------------------------------------------------------- */
    DECLARE
        @MergeOnJoinMV      varchar(max)    = ''
        , @MergeOnJoinCheck varchar(max)    = '';

    DECLARE mergeon3_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT QUOTENAME(TRIM(CAST(value AS varchar(255))))
        FROM STRING_SPLIT(@MergeOnColumns, ',')
        WHERE TRIM(CAST(value AS varchar(255))) <> '';

    OPEN mergeon3_cursor;
    FETCH NEXT FROM mergeon3_cursor INTO @MergeOnCol;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @MergeOnJoinMV <> ''
        BEGIN
            SET @MergeOnJoinMV      = @MergeOnJoinMV      + CHAR(13) + CHAR(10) + '        AND ';
            SET @MergeOnJoinCheck   = @MergeOnJoinCheck    + CHAR(13) + CHAR(10) + '      AND ';
        END;

        SET @MergeOnJoinMV      = @MergeOnJoinMV    + 'src.' + @MergeOnCol + ' = mv.' + @MergeOnCol;
        SET @MergeOnJoinCheck   = @MergeOnJoinCheck + 'tgt_check.' + @MergeOnCol + ' = src.' + @MergeOnCol;

        FETCH NEXT FROM mergeon3_cursor INTO @MergeOnCol;
    END;

    CLOSE mergeon3_cursor;
    DEALLOCATE mergeon3_cursor;

    /* Rebuild INSERT statement with correct alias references */
    SET @InsertSQL = N'
/* ----------------------------------------------------------------
   Step 2: Insert new version rows for changed and new records
---------------------------------------------------------------- */
WITH MaxVersion AS
(
    SELECT
        ' + @MergeOnSelectList + '
        , MAX(' + QUOTENAME(@WH_VersionColumnName) + ') AS __MaxVersion
    FROM ' + @FQTarget + '
    GROUP BY
        ' + @MergeOnSelectList + '
)
INSERT INTO ' + @FQTarget + '
(
' + @InsertColList + '
)
SELECT
' + @InsertValList + '
FROM ' + @FQSource + ' src
/* Derive the new version number.
   New records (no prior version) start at 1.
   Changed records increment from their current MAX. */
CROSS APPLY
(
    SELECT ISNULL(mv.__MaxVersion, 0) + 1 AS __NewVersion
    FROM (SELECT 1 AS __Dummy) AS __One
    LEFT JOIN MaxVersion mv
        ON ' + @MergeOnJoinMV + N'
) AS src_ver
/* Only insert where the active row no longer exists.
   This covers both changed records (retired in step 1a)
   and brand new records (never existed in target). */
WHERE NOT EXISTS
(
    SELECT 1
    FROM ' + @FQTarget + ' tgt_check
    WHERE ' + @MergeOnJoinCheck + N'
      AND tgt_check.' + QUOTENAME(@WH_IsCurrentColumnName) + ' = 1
);
';

    /* Fix the INSERT values list - replace src.__NewVersion with src_ver.__NewVersion */
    SET @InsertValList = REPLACE(@InsertValList, 'src.__NewVersion', 'src_ver.__NewVersion');

    /* Rebuild INSERT SQL with corrected values list */
    SET @InsertSQL = N'
/* ----------------------------------------------------------------
   Step 2: Insert new version rows for changed and new records
---------------------------------------------------------------- */
WITH MaxVersion AS
(
    SELECT
        ' + @MergeOnSelectList + '
        , MAX(' + QUOTENAME(@WH_VersionColumnName) + ') AS __MaxVersion
    FROM ' + @FQTarget + '
    GROUP BY
        ' + @MergeOnSelectList + '
)
INSERT INTO ' + @FQTarget + '
(
' + @InsertColList + '
)
SELECT
' + @InsertValList + '
FROM ' + @FQSource + ' src
/* Derive the new version number.
   New records (no prior version) start at 1.
   Changed records increment from their current MAX. */
CROSS APPLY
(
    SELECT ISNULL(mv.__MaxVersion, 0) + 1 AS __NewVersion
    FROM (SELECT 1 AS __Dummy) AS __One
    LEFT JOIN MaxVersion mv
        ON ' + @MergeOnJoinMV + N'
) AS src_ver
/* Only insert where the active row no longer exists.
   This covers both changed records (retired in step 1a)
   and brand new records (never existed in target). */
WHERE NOT EXISTS
(
    SELECT 1
    FROM ' + @FQTarget + ' tgt_check
    WHERE ' + @MergeOnJoinCheck + N'
      AND tgt_check.' + QUOTENAME(@WH_IsCurrentColumnName) + ' = 1
);
';

    /* ----------------------------------------------------------------
       Debug or Execute
    ---------------------------------------------------------------- */
    IF @DebugMode = 1
    BEGIN
        SELECT @RetireSQL       AS [Step1a_RetireChangedRows];
        SELECT @SoftDeleteSQL   AS [Step1b_SoftDeleteAbsentRows];
        SELECT @InsertSQL       AS [Step2_InsertNewVersionRows];
    END
    ELSE
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;
                EXEC sp_executesql @RetireSQL;

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