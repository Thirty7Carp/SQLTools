/* =====================================================================
   Utility.MRG_TRG_DynamicMergeConfiguration_Upsert
   -----------------------------------------------------------------------
   Fires on INSERT and UPDATE of Utility.MRG_DynamicMergeConfiguration.
   Validates:
     1. QualifiedSourceName exists in its database INFORMATION_SCHEMA.TABLES
     2. QualifiedTargetName exists in its database INFORMATION_SCHEMA.TABLES
     3. QualifiedTargetHistoryName exists in its database INFORMATION_SCHEMA.TABLES (when not NULL)
     4. All MergeOnColumns exist on both source and target
     5. All IgnoreColumns exist on the source
     6. All required WH meta column names (per SCDType) exist on the target,
        falling back to MRG_DynamicMergeConfigurationDefaults when the config row has NULL
     7. All required WH meta column names are present in IgnoreColumns

   All string comparisons are case-insensitive.
   On failure: PRINTs each failure, then raises a generic error.
   ===================================================================== */
CREATE OR ALTER TRIGGER Utility.MRG_TRG_DynamicMergeConfiguration_Upsert
ON [Utility].[MRG_DynamicMergeConfiguration]

INSTEAD OF INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* ----------------------------------------------------------------
       Capture inserted values
    ---------------------------------------------------------------- */
    DECLARE
        @DynamicMergeConfigurationID    int
        , @MergeConfigurationName       varchar(255)
        , @QualifiedSourceName          varchar(500)
        , @QualifiedTargetName          varchar(500)
        , @QualifiedTargetHistoryName   varchar(500)
        , @SCDType                      varchar(10)
        , @MergeOnColumns               varchar(max)
        , @IgnoreColumns                varchar(max)
        , @DeleteIfNotMatchedBySource   bit
        , @WH_CreateDateColumnName      varchar(255)
        , @WH_ModifiedDateColumnName    varchar(255)
        , @WH_ArchivedDateColumnName    varchar(255)
        , @WH_VersionColumnName         varchar(255)
        , @WH_IsCurrentColumnName       varchar(255)
        , @WH_IsDeletedColumnName       varchar(255)
        , @WH_IsDeleted                 bit;

    SELECT
        @DynamicMergeConfigurationID    = DynamicMergeConfigurationID
        , @MergeConfigurationName       = MergeConfigurationName
        , @QualifiedSourceName          = QualifiedSourceName
        , @QualifiedTargetName          = QualifiedTargetName
        , @QualifiedTargetHistoryName   = QualifiedTargetHistoryName
        , @SCDType                      = SCDType
        , @MergeOnColumns               = MergeOnColumns
        , @IgnoreColumns                = IgnoreColumns
        , @DeleteIfNotMatchedBySource   = DeleteIfNotMatchedBySource
        , @WH_CreateDateColumnName      = WH_CreateDateColumnName
        , @WH_ModifiedDateColumnName    = WH_ModifiedDateColumnName
        , @WH_ArchivedDateColumnName    = WH_ArchivedDateColumnName
        , @WH_VersionColumnName         = WH_VersionColumnName
        , @WH_IsCurrentColumnName       = WH_IsCurrentColumnName
        , @WH_IsDeletedColumnName       = WH_IsDeletedColumnName
        , @WH_IsDeleted                 = WH_IsDeleted
    FROM inserted;

    /* ----------------------------------------------------------------
       Parse qualified names into parts
    ---------------------------------------------------------------- */
    DECLARE
        @SourceDB           varchar(255)    = PARSENAME(@QualifiedSourceName, 3)
        , @SourceSchema     varchar(255)    = PARSENAME(@QualifiedSourceName, 2)
        , @SourceTable      varchar(255)    = PARSENAME(@QualifiedSourceName, 1)
        , @TargetDB         varchar(255)    = PARSENAME(@QualifiedTargetName, 3)
        , @TargetSchema     varchar(255)    = PARSENAME(@QualifiedTargetName, 2)
        , @TargetTable      varchar(255)    = PARSENAME(@QualifiedTargetName, 1)
        , @HistoryDB        varchar(255)    = PARSENAME(@QualifiedTargetHistoryName, 3)
        , @HistorySchema    varchar(255)    = PARSENAME(@QualifiedTargetHistoryName, 2)
        , @HistoryTable     varchar(255)    = PARSENAME(@QualifiedTargetHistoryName, 1);

    /* ----------------------------------------------------------------
       Resolve WH meta column names - fall back to defaults where NULL
    ---------------------------------------------------------------- */
    DECLARE
        @Defaults_CreateDate        varchar(255)
        , @Defaults_ModifiedDate    varchar(255)
        , @Defaults_ArchivedDate    varchar(255)
        , @Defaults_Version         varchar(255)
        , @Defaults_IsCurrent       varchar(255)
        , @Defaults_IsDeleted       varchar(255);

    SELECT
        @Defaults_CreateDate        = WH_CreateDateColumnName
        , @Defaults_ModifiedDate    = WH_ModifiedDateColumnName
        , @Defaults_ArchivedDate    = WH_ArchivedDateColumnName
        , @Defaults_Version         = WH_VersionColumnName
        , @Defaults_IsCurrent       = WH_IsCurrentColumnName
        , @Defaults_IsDeleted       = WH_IsDeletedColumnName
    FROM [Utility].[MRG_DynamicMergeConfigurationDefaults];

    DECLARE
        @Resolved_CreateDate        varchar(255)    = ISNULL(@WH_CreateDateColumnName,   @Defaults_CreateDate)
        , @Resolved_ModifiedDate    varchar(255)    = ISNULL(@WH_ModifiedDateColumnName, @Defaults_ModifiedDate)
        , @Resolved_ArchivedDate    varchar(255)    = ISNULL(@WH_ArchivedDateColumnName, @Defaults_ArchivedDate)
        , @Resolved_Version         varchar(255)    = ISNULL(@WH_VersionColumnName,      @Defaults_Version)
        , @Resolved_IsCurrent       varchar(255)    = ISNULL(@WH_IsCurrentColumnName,    @Defaults_IsCurrent)
        , @Resolved_IsDeleted       varchar(255)    = ISNULL(@WH_IsDeletedColumnName,    @Defaults_IsDeleted);

    /* ----------------------------------------------------------------
       Validation state
    ---------------------------------------------------------------- */
    DECLARE
        @HasFailures    bit             = 0
        , @SQL          nvarchar(max)
        , @Exists       bit
        , @ParamDef     nvarchar(500)   = N'@Exists bit OUTPUT';

    /* ================================================================
       1. Validate QualifiedSourceName exists
    ================================================================ */
    SET @SQL = N'
        SELECT @Exists = CASE WHEN EXISTS (
            SELECT 1
            FROM [' + @SourceDB + '].INFORMATION_SCHEMA.TABLES
            WHERE LOWER(TABLE_SCHEMA) = LOWER(''' + @SourceSchema + ''')
              AND LOWER(TABLE_NAME)   = LOWER(''' + @SourceTable  + ''')
        ) THEN 1 ELSE 0 END';

    EXEC sp_executesql @SQL, @ParamDef, @Exists = @Exists OUTPUT;

    IF @Exists = 0
    BEGIN
        PRINT 'Source table does not exist: ' + @QualifiedSourceName;
        SET @HasFailures = 1;
    END;

    /* ================================================================
       2. Validate QualifiedTargetName exists
    ================================================================ */
    SET @SQL = N'
        SELECT @Exists = CASE WHEN EXISTS (
            SELECT 1
            FROM [' + @TargetDB + '].INFORMATION_SCHEMA.TABLES
            WHERE LOWER(TABLE_SCHEMA) = LOWER(''' + @TargetSchema + ''')
              AND LOWER(TABLE_NAME)   = LOWER(''' + @TargetTable  + ''')
        ) THEN 1 ELSE 0 END';

    EXEC sp_executesql @SQL, @ParamDef, @Exists = @Exists OUTPUT;

    IF @Exists = 0
    BEGIN
        PRINT 'Target table does not exist: ' + @QualifiedTargetName;
        SET @HasFailures = 1;
    END;

    /* ================================================================
       3. Validate QualifiedTargetHistoryName exists (when not NULL)
    ================================================================ */
    IF @QualifiedTargetHistoryName IS NOT NULL
    BEGIN
        SET @SQL = N'
            SELECT @Exists = CASE WHEN EXISTS (
                SELECT 1
                FROM [' + @HistoryDB + '].INFORMATION_SCHEMA.TABLES
                WHERE LOWER(TABLE_SCHEMA) = LOWER(''' + @HistorySchema + ''')
                  AND LOWER(TABLE_NAME)   = LOWER(''' + @HistoryTable  + ''')
            ) THEN 1 ELSE 0 END';

        EXEC sp_executesql @SQL, @ParamDef, @Exists = @Exists OUTPUT;

        IF @Exists = 0
        BEGIN
            PRINT 'History table does not exist: ' + @QualifiedTargetHistoryName;
            SET @HasFailures = 1;
        END;
    END;

    /* ================================================================
       4. Validate MergeOnColumns exist on both source and target
    ================================================================ */
    DECLARE @MergeOnCol varchar(255);

    DECLARE mergeon_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT TRIM(CAST(value AS varchar(255)))
        FROM STRING_SPLIT(@MergeOnColumns, ',')
        WHERE TRIM(CAST(value AS varchar(255))) <> '';

    OPEN mergeon_cursor;
    FETCH NEXT FROM mergeon_cursor INTO @MergeOnCol;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        /* Check source */
        SET @SQL = N'
            SELECT @Exists = CASE WHEN EXISTS (
                SELECT 1
                FROM [' + @SourceDB + '].INFORMATION_SCHEMA.COLUMNS
                WHERE LOWER(TABLE_SCHEMA) = LOWER(''' + @SourceSchema + ''')
                  AND LOWER(TABLE_NAME)   = LOWER(''' + @SourceTable  + ''')
                  AND LOWER(COLUMN_NAME)  = LOWER(''' + REPLACE(@MergeOnCol, '''', '''''') + ''')
            ) THEN 1 ELSE 0 END';

        EXEC sp_executesql @SQL, @ParamDef, @Exists = @Exists OUTPUT;

        IF @Exists = 0
        BEGIN
            PRINT 'MergeOnColumn [' + @MergeOnCol + '] does not exist on source: ' + @QualifiedSourceName;
            SET @HasFailures = 1;
        END;

        /* Check target */
        SET @SQL = N'
            SELECT @Exists = CASE WHEN EXISTS (
                SELECT 1
                FROM [' + @TargetDB + '].INFORMATION_SCHEMA.COLUMNS
                WHERE LOWER(TABLE_SCHEMA) = LOWER(''' + @TargetSchema + ''')
                  AND LOWER(TABLE_NAME)   = LOWER(''' + @TargetTable  + ''')
                  AND LOWER(COLUMN_NAME)  = LOWER(''' + REPLACE(@MergeOnCol, '''', '''''') + ''')
            ) THEN 1 ELSE 0 END';

        EXEC sp_executesql @SQL, @ParamDef, @Exists = @Exists OUTPUT;

        IF @Exists = 0
        BEGIN
            PRINT 'MergeOnColumn [' + @MergeOnCol + '] does not exist on target: ' + @QualifiedTargetName;
            SET @HasFailures = 1;
        END;

        FETCH NEXT FROM mergeon_cursor INTO @MergeOnCol;
    END;

    CLOSE mergeon_cursor;
    DEALLOCATE mergeon_cursor;

    /* ================================================================
       5. Validate IgnoreColumns exist on source (when not NULL)
    ================================================================ */
    IF @IgnoreColumns IS NOT NULL
    BEGIN
        DECLARE @IgnoreCol varchar(255);

        DECLARE ignore_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT TRIM(CAST(value AS varchar(255)))
            FROM STRING_SPLIT(@IgnoreColumns, ',')
            WHERE TRIM(CAST(value AS varchar(255))) <> '';

        OPEN ignore_cursor;
        FETCH NEXT FROM ignore_cursor INTO @IgnoreCol;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @SQL = N'
                SELECT @Exists = CASE WHEN EXISTS (
                    SELECT 1
                    FROM [' + @SourceDB + '].INFORMATION_SCHEMA.COLUMNS
                    WHERE LOWER(TABLE_SCHEMA) = LOWER(''' + @SourceSchema + ''')
                      AND LOWER(TABLE_NAME)   = LOWER(''' + @SourceTable  + ''')
                      AND LOWER(COLUMN_NAME)  = LOWER(''' + REPLACE(@IgnoreCol, '''', '''''') + ''')
                ) THEN 1 ELSE 0 END';

            EXEC sp_executesql @SQL, @ParamDef, @Exists = @Exists OUTPUT;

            IF @Exists = 0
            BEGIN
                PRINT 'IgnoreColumn [' + @IgnoreCol + '] does not exist on source: ' + @QualifiedSourceName;
                SET @HasFailures = 1;
            END;

            FETCH NEXT FROM ignore_cursor INTO @IgnoreCol;
        END;

        CLOSE ignore_cursor;
        DEALLOCATE ignore_cursor;
    END;

    /* ================================================================
       6. Validate required WH meta column names exist on target,
          and are present in IgnoreColumns
    ================================================================ */
    DECLARE @RequiredWHColumns TABLE
    (
        ResolvedColumnName  varchar(255)
        , FieldName         varchar(255)
        , CheckHistory      bit
    );

    IF @SCDType = 'SCD1'
        INSERT INTO @RequiredWHColumns VALUES
            (@Resolved_CreateDate,   'WH_CreateDateColumnName',   0)
            , (@Resolved_ModifiedDate, 'WH_ModifiedDateColumnName', 0)
            , (@Resolved_IsDeleted,    'WH_IsDeletedColumnName',    0);
    ELSE IF @SCDType = 'SCD2Date'
        INSERT INTO @RequiredWHColumns VALUES
            (@Resolved_CreateDate,   'WH_CreateDateColumnName',   0)
            , (@Resolved_ModifiedDate, 'WH_ModifiedDateColumnName', 0)
            , (@Resolved_IsDeleted,    'WH_IsDeletedColumnName',    0);
    ELSE IF @SCDType = 'SCD2DateAndCurrent'
        INSERT INTO @RequiredWHColumns VALUES
            (@Resolved_CreateDate,   'WH_CreateDateColumnName',   0)
            , (@Resolved_ModifiedDate, 'WH_ModifiedDateColumnName', 0)
            , (@Resolved_IsCurrent,    'WH_IsCurrentColumnName',    0)
            , (@Resolved_IsDeleted,    'WH_IsDeletedColumnName',    0);
    ELSE IF @SCDType = 'SCD2Version'
        INSERT INTO @RequiredWHColumns VALUES
            (@Resolved_CreateDate,   'WH_CreateDateColumnName',   0)
            , (@Resolved_Version,      'WH_VersionColumnName',      0)
            , (@Resolved_IsCurrent,    'WH_IsCurrentColumnName',    0)
            , (@Resolved_IsDeleted,    'WH_IsDeletedColumnName',    0);
    ELSE IF @SCDType = 'SCD4'
        INSERT INTO @RequiredWHColumns VALUES
            (@Resolved_CreateDate,   'WH_CreateDateColumnName',   0)
            , (@Resolved_ModifiedDate, 'WH_ModifiedDateColumnName', 0)
            , (@Resolved_ArchivedDate, 'WH_ArchivedDateColumnName', 1);

    DECLARE
        @WHCol          varchar(255)
        , @WHFieldName  varchar(255)
        , @WHHistory    bit;

    DECLARE wh_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT ResolvedColumnName, FieldName, CheckHistory
        FROM @RequiredWHColumns;

    OPEN wh_cursor;
    FETCH NEXT FROM wh_cursor INTO @WHCol, @WHFieldName, @WHHistory;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        /* Check column exists on target */
        SET @SQL = N'
            SELECT @Exists = CASE WHEN EXISTS (
                SELECT 1
                FROM [' + @TargetDB + '].INFORMATION_SCHEMA.COLUMNS
                WHERE LOWER(TABLE_SCHEMA) = LOWER(''' + @TargetSchema + ''')
                  AND LOWER(TABLE_NAME)   = LOWER(''' + @TargetTable  + ''')
                  AND LOWER(COLUMN_NAME)  = LOWER(''' + REPLACE(@WHCol, '''', '''''') + ''')
            ) THEN 1 ELSE 0 END';

        EXEC sp_executesql @SQL, @ParamDef, @Exists = @Exists OUTPUT;

        IF @Exists = 0
        BEGIN
            PRINT @WHFieldName + ' [' + @WHCol + '] does not exist on target: ' + @QualifiedTargetName;
            SET @HasFailures = 1;
        END;

        /* Check column exists on history table (SCD4 ArchivedDate only) */
        IF @WHHistory = 1 AND @QualifiedTargetHistoryName IS NOT NULL
        BEGIN
            SET @SQL = N'
                SELECT @Exists = CASE WHEN EXISTS (
                    SELECT 1
                    FROM [' + @HistoryDB + '].INFORMATION_SCHEMA.COLUMNS
                    WHERE LOWER(TABLE_SCHEMA) = LOWER(''' + @HistorySchema + ''')
                      AND LOWER(TABLE_NAME)   = LOWER(''' + @HistoryTable  + ''')
                      AND LOWER(COLUMN_NAME)  = LOWER(''' + REPLACE(@WHCol, '''', '''''') + ''')
                ) THEN 1 ELSE 0 END';

            EXEC sp_executesql @SQL, @ParamDef, @Exists = @Exists OUTPUT;

            IF @Exists = 0
            BEGIN
                PRINT @WHFieldName + ' [' + @WHCol + '] does not exist on history table: ' + @QualifiedTargetHistoryName;
                SET @HasFailures = 1;
            END;
        END;

        /* Check column is present in IgnoreColumns */
        IF NOT EXISTS (
            SELECT 1
            FROM STRING_SPLIT(ISNULL(@IgnoreColumns, ''), ',')
            WHERE LOWER(TRIM(CAST(value AS varchar(255)))) = LOWER(@WHCol)
        )
        BEGIN
            PRINT @WHFieldName + ' [' + @WHCol + '] is not present in IgnoreColumns.';
            SET @HasFailures = 1;
        END;

        FETCH NEXT FROM wh_cursor INTO @WHCol, @WHFieldName, @WHHistory;
    END;

    CLOSE wh_cursor;
    DEALLOCATE wh_cursor;

    /* ================================================================
       Raise generic error if any validation failures occurred
    ================================================================ */
    IF @HasFailures = 1
    BEGIN
        RAISERROR('Validation failed. See above for details.', 16, 1);
        RETURN;
    END;

    /* ================================================================
       Perform the actual INSERT or UPDATE
    ================================================================ */
    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        UPDATE tgt
        SET
            MergeConfigurationName          = i.MergeConfigurationName
            , QualifiedSourceName           = i.QualifiedSourceName
            , QualifiedTargetName           = i.QualifiedTargetName
            , QualifiedTargetHistoryName    = i.QualifiedTargetHistoryName
            , SCDType                       = i.SCDType
            , MergeOnColumns                = i.MergeOnColumns
            , IgnoreColumns                 = i.IgnoreColumns
            , DeleteIfNotMatchedBySource    = i.DeleteIfNotMatchedBySource
            , WH_CreateDateColumnName       = i.WH_CreateDateColumnName
            , WH_ModifiedDateColumnName     = i.WH_ModifiedDateColumnName
            , WH_ArchivedDateColumnName     = i.WH_ArchivedDateColumnName
            , WH_VersionColumnName          = i.WH_VersionColumnName
            , WH_IsCurrentColumnName        = i.WH_IsCurrentColumnName
            , WH_IsDeletedColumnName        = i.WH_IsDeletedColumnName
            , WH_IsDeleted                  = i.WH_IsDeleted
            , WH_ModifiedDateTime_UTC       = GETUTCDATE()
        FROM [Utility].[MRG_DynamicMergeConfiguration] tgt
        INNER JOIN inserted i ON tgt.DynamicMergeConfigurationID = i.DynamicMergeConfigurationID;
    END
    ELSE
    BEGIN
        INSERT INTO [Utility].[MRG_DynamicMergeConfiguration]
        (
            MergeConfigurationName
            , QualifiedSourceName
            , QualifiedTargetName
            , QualifiedTargetHistoryName
            , SCDType
            , MergeOnColumns
            , IgnoreColumns
            , DeleteIfNotMatchedBySource
            , WH_CreateDateColumnName
            , WH_ModifiedDateColumnName
            , WH_ArchivedDateColumnName
            , WH_VersionColumnName
            , WH_IsCurrentColumnName
            , WH_IsDeletedColumnName
            , WH_IsDeleted
        )
        SELECT
            MergeConfigurationName
            , QualifiedSourceName
            , QualifiedTargetName
            , QualifiedTargetHistoryName
            , SCDType
            , MergeOnColumns
            , IgnoreColumns
            , DeleteIfNotMatchedBySource
            , WH_CreateDateColumnName
            , WH_ModifiedDateColumnName
            , WH_ArchivedDateColumnName
            , WH_VersionColumnName
            , WH_IsCurrentColumnName
            , WH_IsDeletedColumnName
            , WH_IsDeleted
        FROM inserted;
    END;

END;