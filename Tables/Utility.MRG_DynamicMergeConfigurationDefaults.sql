/* =====================================================================
   Utility.MRG_DynamicMergeConfigurationDefaults
   -----------------------------------------------------------------------
   Stores global default column names for the dynamic merge configuration.
   These defaults are used when a config row has NULL for a required column
   name field for its SCD type.

   Only one row can ever exist in this table.
   ===================================================================== */
CREATE TABLE [Utility].[MRG_DynamicMergeConfigurationDefaults]
(
    DynamicMergeConfigurationDefaultsID    int             NOT NULL IDENTITY(1,1)
    /* Default Target Meta Column Names */
    , WH_CreateDateColumnName              varchar(255)    NULL
    , WH_ModifiedDateColumnName            varchar(255)    NULL
    , WH_RowEffectiveDateColumnName        varchar(255)    NULL
    , WH_RowExpirationDateColumnName       varchar(255)    NULL
    , WH_RowExpirationDateValue            varchar(255)    NULL
    , WH_VersionColumnName                 varchar(255)    NULL
    , WH_isCurrentColumnName               varchar(255)    NULL
    , WH_isDeletedColumnName               varchar(255)    NULL
    /* UTC Offset */
    , WH_UTCOffset                         smallint        NULL
    /* Config Record Meta Data */
    , WH_CreateDateTime_UTC                datetime2       NOT NULL DEFAULT GETUTCDATE()
    , WH_ModifiedDateTime_UTC              datetime2       NOT NULL DEFAULT GETUTCDATE()
    /* Enforce single row */
    , CONSTRAINT CHK_Utility_MRG_DynamicMergeConfigurationDefaults_SingleRow
        CHECK (DynamicMergeConfigurationDefaultsID = 1)
);