/* =====================================================================
   Insert default values into Utility.MRG_DynamicMergeConfigurationDefaults
   ===================================================================== */
INSERT INTO [Utility].[MRG_DynamicMergeConfigurationDefaults]
(
    WH_CreateDateColumnName
    , WH_ModifiedDateColumnName
    , WH_ArchivedDateColumnName
    , WH_VersionColumnName
    , WH_IsCurrentColumnName
    , WH_IsDeletedColumnName
)
VALUES
(
    'WH_CreateDateTime_UTC'
    , 'WH_ModifiedDateTime_UTC'
    , 'WH_ArchivedDateTime_UTC'
    , 'WH_Version'
    , 'WH_IsCurrent'
    , 'WH_IsDeleted'
);