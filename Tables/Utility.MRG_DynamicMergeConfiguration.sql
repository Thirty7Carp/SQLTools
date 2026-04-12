

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
    , WH_RowExpirationDateValue         datetime2       NULL
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
);

/* One row per configuration name */
CREATE UNIQUE INDEX UX_UTILITY_MergeConfigurationName
    ON [Utility].[MRG_DynamicMergeConfiguration] (MergeConfigurationName);