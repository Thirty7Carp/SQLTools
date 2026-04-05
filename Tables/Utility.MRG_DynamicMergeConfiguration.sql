CREATE TABLE [Utility].[MRG_DynamicMergeConfiguration]
(
    DynamicMergeConfigurationID     int             NOT NULL IDENTITY(1,1)
    /* The name used for the execute */
    , MergeConfigurationName        varchar(255)    NOT NULL
    /* Source/Target Objects */
    , QualifiedSourceName           varchar(500)    NOT NULL
    , QualifiedTargetName           varchar(500)    NOT NULL
    , QualifiedTargetHistoryName    varchar(500)    NULL
    /* Merge Rules */
    , SCDType                       varchar(10)     NOT NULL
    , MergeOnColumns                varchar(max)    NOT NULL
    , IgnoreColumns                 varchar(max)    NULL
    , DeleteIfNotMatchedBySource    bit             NOT NULL DEFAULT 0
    , IgnoreIdentityColumns         bit             NOT NULL DEFAULT 1
    /* Target Meta Column Names */
    , WH_CreateDateColumnName           varchar(255)    NULL
    , WH_ModifiedDateColumnName         varchar(255)    NULL
    , WH_RowEffectiveDateColumnName     varchar(255)    NULL
    , WH_RowExpirationDateColumnName    varchar(255)    NULL
    , WH_RowEffExDateType               varchar(10)     NULL
    , WH_VersionColumnName              varchar(255)    NULL
    , WH_IsCurrentColumnName            varchar(255)    NULL
    , WH_isDeletedColumnName            varchar(255)    NULL
    /* UTC Offset */
    , WH_UTCOffset                  smallint        NULL
    /* Config Record Meta Data */
    , WH_CreateDateTime_UTC         datetime2       NOT NULL DEFAULT GETUTCDATE()
    , WH_ModifiedDateTime_UTC       datetime2       NOT NULL DEFAULT GETUTCDATE()
    /* Format Checks */
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_SCDType
        CHECK (SCDType IN ('SCD1', 'SCD2Version', 'SCD2Date', 'SCD2DateAndCurrent', 'SCD4'))
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_QualifiedSourceName
        CHECK (QualifiedSourceName LIKE '%.%.%')
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_QualifiedTargetName
        CHECK (QualifiedTargetName LIKE '%.%.%')
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_QualifiedTargetHistoryName
        CHECK (QualifiedTargetHistoryName IS NULL OR QualifiedTargetHistoryName LIKE '%.%.%')
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_WH_RowEffExDateType
        CHECK (WH_RowEffExDateType IS NULL OR WH_RowEffExDateType IN ('date', 'datetime', 'datetime2'))

    /* ----------------------------------------------------------------
       SCD1
       - No history kept, rows are overwritten
       - Hard delete if not matched by source
       - Requires: CreateDate, ModifiedDate
       - Must be NULL: TargetHistory, RowEffective, RowExpiration,
                       EffExDateType, Version, IsCurrent, IsDeleted
    ---------------------------------------------------------------- */
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_SCD1 CHECK
        (
        SCDType != 'SCD1'
        OR  (
            /* Required - NOT NULL */
            MergeConfigurationName              IS NOT NULL
            AND QualifiedSourceName             IS NOT NULL
            AND QualifiedTargetName             IS NOT NULL
            AND MergeOnColumns                  IS NOT NULL
            AND DeleteIfNotMatchedBySource       IS NOT NULL
            AND WH_CreateDateColumnName         IS NOT NULL
            AND WH_ModifiedDateColumnName       IS NOT NULL
            /* Must be NULL */
            AND QualifiedTargetHistoryName      IS NULL
            AND WH_RowEffectiveDateColumnName   IS NULL
            AND WH_RowExpirationDateColumnName  IS NULL
            AND WH_RowEffExDateType             IS NULL
            AND WH_VersionColumnName            IS NULL
            AND WH_IsCurrentColumnName          IS NULL
            AND WH_isDeletedColumnName          IS NULL
            )
        )

    /* ----------------------------------------------------------------
       SCD2Date
       - History via date ranges
       - Requires: CreateDate, ModifiedDate, IsDeleted,
                   RowEffectiveDate, RowExpirationDate, EffExDateType
       - Must be NULL: TargetHistory, Version, IsCurrent
    ---------------------------------------------------------------- */
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_SCD2Date CHECK
        (
        SCDType != 'SCD2Date'
        OR  (
            /* Required - NOT NULL */
            MergeConfigurationName              IS NOT NULL
            AND QualifiedSourceName             IS NOT NULL
            AND QualifiedTargetName             IS NOT NULL
            AND MergeOnColumns                  IS NOT NULL
            AND DeleteIfNotMatchedBySource      IS NOT NULL
            AND WH_CreateDateColumnName         IS NOT NULL
            AND WH_ModifiedDateColumnName       IS NOT NULL
            AND WH_isDeletedColumnName          IS NOT NULL
            AND WH_RowEffectiveDateColumnName   IS NOT NULL
            AND WH_RowExpirationDateColumnName  IS NOT NULL
            AND WH_RowEffExDateType             IS NOT NULL
            /* Must be NULL */
            AND QualifiedTargetHistoryName      IS NULL
            AND WH_VersionColumnName            IS NULL
            AND WH_IsCurrentColumnName          IS NULL
            )
        )

    /* ----------------------------------------------------------------
       SCD2DateAndCurrent
       - History via date ranges + IsCurrent flag
       - Requires: CreateDate, ModifiedDate, IsCurrent, IsDeleted,
                   RowEffectiveDate, RowExpirationDate, EffExDateType
       - Must be NULL: TargetHistory, Version
    ---------------------------------------------------------------- */
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_SCD2DateAndCurrent CHECK
        (
        SCDType != 'SCD2DateAndCurrent'
        OR  (
            /* Required - NOT NULL */
            MergeConfigurationName              IS NOT NULL
            AND QualifiedSourceName             IS NOT NULL
            AND QualifiedTargetName             IS NOT NULL
            AND MergeOnColumns                  IS NOT NULL
            AND DeleteIfNotMatchedBySource      IS NOT NULL
            AND WH_CreateDateColumnName         IS NOT NULL
            AND WH_ModifiedDateColumnName       IS NOT NULL
            AND WH_IsCurrentColumnName          IS NOT NULL
            AND WH_isDeletedColumnName          IS NOT NULL
            AND WH_RowEffectiveDateColumnName   IS NOT NULL
            AND WH_RowExpirationDateColumnName  IS NOT NULL
            AND WH_RowEffExDateType             IS NOT NULL
            /* Must be NULL */
            AND QualifiedTargetHistoryName      IS NULL
            AND WH_VersionColumnName            IS NULL
            )
        )

    /* ----------------------------------------------------------------
       SCD2Version
       - History via version number + IsCurrent flag
       - Requires: CreateDate, Version, IsCurrent, IsDeleted
       - Must be NULL: TargetHistory, ModifiedDate,
                       RowEffective, RowExpiration, EffExDateType
    ---------------------------------------------------------------- */
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_SCD2Version CHECK
        (
        SCDType != 'SCD2Version'
        OR  (
            /* Required - NOT NULL */
            MergeConfigurationName              IS NOT NULL
            AND QualifiedSourceName             IS NOT NULL
            AND QualifiedTargetName             IS NOT NULL
            AND MergeOnColumns                  IS NOT NULL
            AND DeleteIfNotMatchedBySource      IS NOT NULL
            AND WH_CreateDateColumnName         IS NOT NULL
            AND WH_VersionColumnName            IS NOT NULL
            AND WH_IsCurrentColumnName          IS NOT NULL
            AND WH_isDeletedColumnName          IS NOT NULL
            /* Must be NULL */
            AND QualifiedTargetHistoryName      IS NULL
            AND WH_ModifiedDateColumnName       IS NULL
            AND WH_RowEffectiveDateColumnName   IS NULL
            AND WH_RowExpirationDateColumnName  IS NULL
            AND WH_RowEffExDateType             IS NULL
            )
        )

    /* ----------------------------------------------------------------
       SCD4
       - Current row in main table, history in separate history table
       - Old row moved to history on change or delete
       - Requires: CreateDate, TargetHistory
       - Must be NULL: ModifiedDate, RowEffective, RowExpiration,
                       EffExDateType, Version, IsCurrent, IsDeleted
    ---------------------------------------------------------------- */
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_SCD4 CHECK
        (
        SCDType != 'SCD4'
        OR  (
            /* Required - NOT NULL */
            MergeConfigurationName              IS NOT NULL
            AND QualifiedSourceName             IS NOT NULL
            AND QualifiedTargetName             IS NOT NULL
            AND QualifiedTargetHistoryName      IS NOT NULL
            AND MergeOnColumns                  IS NOT NULL
            AND DeleteIfNotMatchedBySource      IS NOT NULL
            AND WH_CreateDateColumnName         IS NOT NULL
            /* Must be NULL */
            AND WH_ModifiedDateColumnName       IS NULL
            AND WH_RowEffectiveDateColumnName   IS NULL
            AND WH_RowExpirationDateColumnName  IS NULL
            AND WH_RowEffExDateType             IS NULL
            AND WH_VersionColumnName            IS NULL
            AND WH_IsCurrentColumnName          IS NULL
            AND WH_isDeletedColumnName          IS NULL
            )
        )
);

/* One row per configuration name */
CREATE UNIQUE INDEX UX_UTILITY_MergeConfigurationName
    ON [Utility].[MRG_DynamicMergeConfiguration] (MergeConfigurationName);