/* =====================================================================
   Insert default values into Utility.MRG_DynamicMergeConfigurationDefaults
   ===================================================================== */

Truncate table [Utility].[MRG_DynamicMergeConfigurationDefaults]

INSERT INTO [Utility].[MRG_DynamicMergeConfigurationDefaults]
(
    WH_CreateDateColumnName
    , WH_ModifiedDateColumnName
    , WH_RowEffectiveDateColumnName
    , WH_RowExpirationDateColumnName
    , WH_RowEffExDateType
    , WH_VersionColumnName
    , WH_isCurrentColumnName
    , WH_isDeletedColumnName
    , WH_UTCOffset
)
VALUES
(
    'WH_CreateDateTime_UTC'
    , 'WH_ModifiedDateTime_UTC'
    , 'WH_RowEffectiveDateTime_UTC'
    , 'WH_RowExpirationDateTime_UTC'
    , 'datetime2'
    , 'WH_Version'
    , 'WH_isCurrent'
    , 'WH_isDeleted'
    , 0
);