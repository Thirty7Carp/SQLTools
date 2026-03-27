CREATE TABLE [Utility].[MRG_DynamicMergeConfiguration]
(
    DynamicMergeConfigurationID   int               NOT NULL IDENTITY(1,1)
    /* The name used for the execute */
    , MergeConfigurationName        varchar(255)    NOT NULL
    /* Source/Target Objects */
    , QualifiedSourceName           varchar(500)    NOT NULL
    , QualifiedTargetName           varchar(500)    NOT NULL
    , QualifiedTargetHistoryName    varchar(500)    NULL
    , IsActive                      bit             NOT NULL DEFAULT 1
    /* Merge Rules */
    , SCDType                       varchar(10)     NOT NULL
    , ColumnMergeOn                 varchar(max)    NOT NULL
    , ColumnIgnore                  varchar(max)    NULL
    , DeleteIfNotMatchedBySource    bit             NOT NULL DEFAULT 0
    /* Target Meta Date Column Names */
    , WH_CreateDateColumnName       varchar(255)    NULL
    , WH_ModifiedDateColumnName     varchar(255)    NULL
    , WH_VersionColumnName          varchar(255)    NULL
    , WH_IsCurrentColumnName        varchar(255)    NULL
    , WH_IsDeletedColumnName        varchar(255)    NULL
    /* Meta Data Column Names */
    , WH_CreateDateTime_UTC         datetime2       NOT NULL DEFAULT GETUTCDATE()
    , WH_ModifiedDateTime_UTC       datetime2       NULL
    , WH_IsDeleted                  bit             NOT NULL DEFAULT 0
    /* Format Checks */
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_SCDType                    CHECK (SCDType IN ('SCD1', 'SCD2Version', 'SCD2Date', 'SCD2DateAndCurrent', 'SCD4'))
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_QualifiedSourceName        CHECK (QualifiedSourceName LIKE '%.%.%')
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_QualifiedTargetName        CHECK (QualifiedTargetName LIKE '%.%.%')
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_QualifiedTargetHistoryName CHECK (QualifiedTargetHistoryName IS NULL OR QualifiedTargetHistoryName LIKE '%.%.%')
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_SCD1 CHECK 
        (
        SCDType != 'SCD1'
        OR  (
            /* Required - NOT NULL */
            MergeConfigurationName          IS NOT NULL
            AND QualifiedSourceName         IS NOT NULL
            AND QualifiedTargetName         IS NOT NULL
            AND ColumnMergeOn               IS NOT NULL
            AND DeleteIfNotMatchedBySource  IS NOT NULL
            AND WH_CreateDateColumnName     IS NOT NULL
            AND WH_ModifiedDateColumnName   IS NOT NULL
            /* Must be NULL */
            AND QualifiedTargetHistoryName  IS NULL
            AND WH_VersionColumnName        IS NULL
            AND WH_IsCurrentColumnName      IS NULL
            )
        )
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_SCD2Date CHECK
        /* Exactly the same as SCD1, but a Unique Constraint specifically for SCD2 */
        (
        SCDType != 'SCD2Date'
        OR  (
            /* Required - NOT NULL */
            MergeConfigurationName          IS NOT NULL
            AND QualifiedSourceName         IS NOT NULL
            AND QualifiedTargetName         IS NOT NULL
            AND ColumnMergeOn               IS NOT NULL
            AND DeleteIfNotMatchedBySource  IS NOT NULL
            AND WH_CreateDateColumnName     IS NOT NULL
            AND WH_ModifiedDateColumnName   IS NOT NULL
            /* Must be NULL */
            AND QualifiedTargetHistoryName  IS NULL
            AND WH_VersionColumnName        IS NULL
            AND WH_IsCurrentColumnName      IS NULL
            )
        )
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_SCD2DateAndCurrent CHECK
        (
        SCDType != 'SCD2DateAndCurrent'
        OR  (
            /* Required - NOT NULL */
            MergeConfigurationName          IS NOT NULL
            AND QualifiedSourceName         IS NOT NULL
            AND QualifiedTargetName         IS NOT NULL
            AND ColumnMergeOn               IS NOT NULL
            AND DeleteIfNotMatchedBySource  IS NOT NULL
            AND WH_CreateDateColumnName     IS NOT NULL
            AND WH_ModifiedDateColumnName   IS NOT NULL
            AND WH_IsCurrentColumnName      IS NOT NULL
            /* Must be NULL */
            AND QualifiedTargetHistoryName  IS NULL
            AND WH_VersionColumnName        IS NULL
            )
        )
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_SCD2Version CHECK
        (
        SCDType != 'SCD2Version'
        OR  (
            /* Required - NOT NULL */
            MergeConfigurationName          IS NOT NULL
            AND QualifiedSourceName         IS NOT NULL
            AND QualifiedTargetName         IS NOT NULL
            AND ColumnMergeOn               IS NOT NULL
            AND DeleteIfNotMatchedBySource  IS NOT NULL
            AND WH_CreateDateColumnName     IS NOT NULL
            AND WH_VersionColumnName        IS NOT NULL
            AND WH_IsCurrentColumnName      IS NOT NULL
            /* Must be NULL */
            AND QualifiedTargetHistoryName  IS NULL
            AND WH_ModifiedDateColumnName   IS NULL
            )
        )
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfiguration_SCD4 CHECK
        (
        SCDType != 'SCD4'
        OR  (
            /* Required - NOT NULL */
            MergeConfigurationName          IS NOT NULL
            AND QualifiedSourceName         IS NOT NULL
            AND QualifiedTargetName         IS NOT NULL
            AND QualifiedTargetHistoryName  IS NOT NULL
            AND ColumnMergeOn               IS NOT NULL
            AND DeleteIfNotMatchedBySource  IS NOT NULL
            AND WH_CreateDateColumnName     IS NOT NULL
            AND WH_ModifiedDateColumnName   IS NOT NULL
            /* Must be NULL */
            AND WH_VersionColumnName        IS NULL
            AND WH_IsCurrentColumnName      IS NULL
            )
        )
);
/* Single active row per Configuration name */
CREATE UNIQUE INDEX UX_UTILITY_MergeConfigurationName_Active
    ON [Utility].[MRG_DynamicMergeConfiguration] (MergeConfigurationName)
    WHERE IsActive = 1 AND WH_IsDeleted = 0;


/* Add Cosntraints about what column names must be entered for each type */