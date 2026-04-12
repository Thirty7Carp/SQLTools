IF OBJECT_ID('Utility.MRG_ExecuteMerge', 'P') IS NOT NULL
    DROP PROCEDURE Utility.MRG_ExecuteMerge;
GO

/* =====================================================================
   Utility.MRG_ExecuteMerge
   -----------------------------------------------------------------------
   Router proc - looks up SCDType from the configuration table and calls
   the relevant SCD merge procedure.

   Parameters:
       @MergeConfigurationName     - The name of the merge configuration
       @DebugMode                  - 1 = print dynamic SQL, 0 = execute
   ===================================================================== */
CREATE PROCEDURE Utility.MRG_ExecuteMerge
    @MergeConfigurationName     varchar(255)
    , @DebugMode                bit             = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SCDType varchar(10);

    /* ----------------------------------------------------------------
       Look up the configuration
    ---------------------------------------------------------------- */
    SELECT @SCDType = SCDType
    FROM Utility.MRG_DynamicMergeConfiguration
    WHERE MergeConfigurationName = @MergeConfigurationName;

    /* ----------------------------------------------------------------
       Validate the configuration exists
    ---------------------------------------------------------------- */
    IF @SCDType IS NULL
    BEGIN
        PRINT 'That Merge Configuration Name does not exist.';
        RETURN;
    END;

    /* ----------------------------------------------------------------
       Route to the relevant SCD procedure
    ---------------------------------------------------------------- */
    IF @SCDType = 'SCD1'
    BEGIN
        EXEC Utility.MRG_processSCD1
            @MergeConfigurationName = @MergeConfigurationName
            , @DebugMode            = @DebugMode;
    END
    ELSE IF @SCDType = 'SCD2Date'
    BEGIN
        EXEC Utility.MRG_processSCD2Date
            @MergeConfigurationName = @MergeConfigurationName
            , @DebugMode            = @DebugMode;
    END
    ELSE IF @SCDType = 'SCD2DateAndCurrent'
    BEGIN
        EXEC Utility.MRG_processSCD2DateAndCurrent
            @MergeConfigurationName = @MergeConfigurationName
            , @DebugMode            = @DebugMode;
    END
    ELSE IF @SCDType = 'SCD2Version'
    BEGIN
        EXEC Utility.MRG_processSCD2Version
            @MergeConfigurationName = @MergeConfigurationName
            , @DebugMode            = @DebugMode;
    END
    ELSE IF @SCDType = 'SCD4'
    BEGIN
        EXEC Utility.MRG_processSCD4
            @MergeConfigurationName = @MergeConfigurationName
            , @DebugMode            = @DebugMode;
    END
    ELSE
    BEGIN
        /* Should never hit this given the CHECK constraint on SCDType,
           but included as a safety net */
        PRINT 'Unrecognised SCDType: ' + @SCDType;
        RETURN;
    END;

END;