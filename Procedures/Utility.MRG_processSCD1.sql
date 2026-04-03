/* =====================================================================
   Utility.MRG_processSCD1
   -----------------------------------------------------------------------
   Performs a dynamic SCD Type 1 merge based on configuration stored in
   Utility.MRG_DynamicMergeConfiguration.

   SCD1 Behaviour:
     - Matched + Changed     : UPDATE all non-key/non-ignored columns
                               Set WH_ModifiedDate = now
     - Not Matched by Target : INSERT new row
                               Set WH_CreateDate = now
                               Set WH_ModifiedDate = now
     - Not Matched by Source : Hard DELETE if DeleteIfNotMatchedBySource = 1

   Parameters:
     @MergeConfigurationName : Name of the config row to use
     @DebugMode              : 1 = PRINT dynamic SQL instead of executing
   ===================================================================== */
CREATE OR ALTER PROCEDURE Utility.MRG_processSCD1
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
        , @WH_CreateDateColumnName      = ISNULL(cfg.WH_CreateDateColumnName,   def.WH_CreateDateColumnName)
        , @WH_ModifiedDateColumnName    = ISNULL(cfg.WH_ModifiedDateColumnName, def.WH_ModifiedDateColumnName)
        , @WH_UTCOffset                 = ISNULL(cfg.WH_UTCOffset, ISNULL(def.WH_UTCOffset, 0))
    FROM Utility.MRG_DynamicMergeConfiguration cfg
    CROSS JOIN Utility.MRG_DynamicMergeConfigurationDefaults def
    WHERE cfg.MergeConfigurationName = @MergeConfigurationName
      AND cfg.WH_IsDeleted = 0;

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
       Resolve current timestamp with UTC offset
    ---------------------------------------------------------------- */
    DECLARE @Now datetime2 = DATEADD(MINUTE, @WH_UTCOffset, GETUTCDATE());

    /* ----------------------------------------------------------------
       Build excluded columns list
       Excludes: MergeOnColumns, IgnoreColumns, WH meta columns,
                 and identity columns on target (if IgnoreIdentityColumns = 1)
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
       Build update/except column lists via cursor
       Cross-references source and target columns, excluding identity
       columns on the target when IgnoreIdentityColumns = 1
    ---------------------------------------------------------------- */
    DECLARE
        @UpdateColumnList   varchar(max)    = ''
        , @ExceptSourceList varchar(max)    = ''
        , @ExceptTargetList varchar(max)    = ''
        , @ColName          varchar(255);

    DECLARE col_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT QUOTENAME(CAST(src.COLUMN_NAME AS varchar(max)))
        FROM sys.columns tgt_col
        INNER JOIN sys.objects tgt_obj  ON tgt_col.object_id = tgt_obj.object_id
        INNER JOIN sys.schemas tgt_sch  ON tgt_obj.schema_id = tgt_sch.schema_id
        CROSS APPLY (
            SELECT COLUMN_NAME
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE LOWER(TABLE_SCHEMA) = LOWER(@SourceSchema)
              AND LOWER(TABLE_NAME)   = LOWER(@SourceTable)
              AND LOWER(COLUMN_NAME)  = LOWER(CAST(tgt_col.name AS varchar(255)))
        ) src
        WHERE LOWER(tgt_sch.name)                           = LOWER(@TargetSchema)
          AND LOWER(tgt_obj.name)                           = LOWER(@TargetTable)
          AND LOWER(CAST(tgt_col.name AS varchar(255)))     NOT IN (SELECT ColumnName FROM @ExcludedColumns)
          AND (@IgnoreIdentityColumns = 0 OR tgt_col.is_identity = 0);

    OPEN col_cursor;
    FETCH NEXT FROM col_cursor INTO @ColName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @UpdateColumnList   = @UpdateColumnList  + '        tgt.' + @ColName + ' = src.' + @ColName + CHAR(13) + CHAR(10) + '        , ';
        SET @ExceptSourceList   = @ExceptSourceList  + '        src.' + @ColName + CHAR(13) + CHAR(10) + '        , ';
        SET @ExceptTargetList   = @ExceptTargetList  + '        tgt.' + @ColName + CHAR(13) + CHAR(10) + '        , ';

        FETCH NEXT FROM col_cursor INTO @ColName;
    END;

    CLOSE col_cursor;
    DEALLOCATE col_cursor;

    /* Remove trailing commas */
    SET @UpdateColumnList   = LEFT(@UpdateColumnList,   LEN(@UpdateColumnList)   - 3);
    SET @ExceptSourceList   = LEFT(@ExceptSourceList,   LEN(@ExceptSourceList)   - 3);
    SET @ExceptTargetList   = LEFT(@ExceptTargetList,   LEN(@ExceptTargetList)   - 3);

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

        FETCH NEXT FROM mergeon_cursor INTO @MergeOnCol;
    END;

    CLOSE mergeon_cursor;
    DEALLOCATE mergeon_cursor;

    /* ----------------------------------------------------------------
       Build INSERT column and value lists
       (MergeOn columns + update columns + WH meta columns)
    ---------------------------------------------------------------- */
    DECLARE
        @InsertColList  varchar(max)    = ''
        , @InsertValList varchar(max)   = ''
        , @MergeOnCol2  varchar(255);

    /* Add MergeOn columns */
    DECLARE mergeon_cursor2 CURSOR LOCAL FAST_FORWARD FOR
        SELECT QUOTENAME(TRIM(CAST(value AS varchar(255))))
        FROM STRING_SPLIT(@MergeOnColumns, ',')
        WHERE TRIM(CAST(value AS varchar(255))) <> '';

    OPEN mergeon_cursor2;
    FETCH NEXT FROM mergeon_cursor2 INTO @MergeOnCol2;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @InsertColList = @InsertColList + '        ' + @MergeOnCol2 + CHAR(13) + CHAR(10) + '        , ';
        SET @InsertValList = @InsertValList + '        src.' + @MergeOnCol2 + CHAR(13) + CHAR(10) + '        , ';
        FETCH NEXT FROM mergeon_cursor2 INTO @MergeOnCol2;
    END;

    CLOSE mergeon_cursor2;
    DEALLOCATE mergeon_cursor2;

    /* Add update columns */
    DECLARE col_cursor2 CURSOR LOCAL FAST_FORWARD FOR
        SELECT QUOTENAME(CAST(src.COLUMN_NAME AS varchar(max)))
        FROM sys.columns tgt_col
        INNER JOIN sys.objects tgt_obj  ON tgt_col.object_id = tgt_obj.object_id
        INNER JOIN sys.schemas tgt_sch  ON tgt_obj.schema_id = tgt_sch.schema_id
        CROSS APPLY (
            SELECT COLUMN_NAME
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE LOWER(TABLE_SCHEMA) = LOWER(@SourceSchema)
              AND LOWER(TABLE_NAME)   = LOWER(@SourceTable)
              AND LOWER(COLUMN_NAME)  = LOWER(CAST(tgt_col.name AS varchar(255)))
        ) src
        WHERE LOWER(tgt_sch.name)                           = LOWER(@TargetSchema)
          AND LOWER(tgt_obj.name)                           = LOWER(@TargetTable)
          AND LOWER(CAST(tgt_col.name AS varchar(255)))     NOT IN (SELECT ColumnName FROM @ExcludedColumns)
          AND (@IgnoreIdentityColumns = 0 OR tgt_col.is_identity = 0);

    OPEN col_cursor2;
    FETCH NEXT FROM col_cursor2 INTO @ColName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @InsertColList = @InsertColList + '        ' + @ColName + CHAR(13) + CHAR(10) + '        , ';
        SET @InsertValList = @InsertValList + '        src.' + @ColName + CHAR(13) + CHAR(10) + '        , ';
        FETCH NEXT FROM col_cursor2 INTO @ColName;
    END;

    CLOSE col_cursor2;
    DEALLOCATE col_cursor2;

    /* Add WH meta columns - SCD1 has no IsDeleted */
    SET @InsertColList = @InsertColList
        + '        ' + QUOTENAME(@WH_CreateDateColumnName)   + CHAR(13) + CHAR(10) + '        , '
        + '        ' + QUOTENAME(@WH_ModifiedDateColumnName);

    SET @InsertValList = @InsertValList
        + '        ''' + CONVERT(varchar, @Now, 121) + '''' + CHAR(13) + CHAR(10) + '        , '
        + '        ''' + CONVERT(varchar, @Now, 121) + '''';

    /* ----------------------------------------------------------------
       Build final MERGE statement
    ---------------------------------------------------------------- */
    DECLARE @MergeSQL nvarchar(max) = N'
MERGE ' + QUOTENAME(@TargetDB) + '.' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@TargetTable) + ' AS tgt
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
        , tgt.' + QUOTENAME(@WH_ModifiedDateColumnName) + ' = ''' + CONVERT(varchar, @Now, 121) + '''

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
        PRINT @MergeSQL;
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