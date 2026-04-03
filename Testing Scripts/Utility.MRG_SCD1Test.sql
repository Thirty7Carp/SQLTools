/* =====================================================================
   Test Script - SQLTools.Utility.MRG_processSCD1
   -----------------------------------------------------------------------
   Creates test source and target tables in TestData.Test schema,
   inserts test data to cover all merge scenarios, then runs the merge
   and shows before/after results.

   Scenarios covered:
     1. Row exists in both, no change         -> No action
     2. Row exists in both, data changed      -> UPDATE
     3. Row exists in source, not in target   -> INSERT
     4. Row exists in target, not in source   -> Hard DELETE (DeleteIfNotMatchedBySource = 1)

   Objects created:
     TestData.Test.MRG_SCD1_Source
     TestData.Test.MRG_SCD1_Target
     SQLTools.Utility.MRG_DynamicMergeConfiguration row: 'Test_SCD1'
   ===================================================================== */

/* ================================================================
   STEP 1 - Create source table
================================================================ */
IF OBJECT_ID('TestData.Test.MRG_SCD1_Source', 'U') IS NOT NULL
    DROP TABLE TestData.Test.MRG_SCD1_Source;

CREATE TABLE TestData.Test.MRG_SCD1_Source
(
    CustomerID      int             NOT NULL
    , FirstName     varchar(100)    NOT NULL
    , LastName      varchar(100)    NOT NULL
    , Email         varchar(255)    NOT NULL
    , Country       varchar(100)    NOT NULL
);

/* ================================================================
   STEP 2 - Create target table
================================================================ */
IF OBJECT_ID('TestData.Test.MRG_SCD1_Target', 'U') IS NOT NULL
    DROP TABLE TestData.Test.MRG_SCD1_Target;

CREATE TABLE TestData.Test.MRG_SCD1_Target
(
    CustomerID              int             NOT NULL
    , FirstName             varchar(100)    NOT NULL
    , LastName              varchar(100)    NOT NULL
    , Email                 varchar(255)    NOT NULL
    , Country               varchar(100)    NOT NULL
    , WH_CreateDateTime_UTC datetime2       NOT NULL
    , WH_ModifiedDateTime_UTC datetime2     NOT NULL
);

/* ================================================================
   STEP 3 - Insert source data
   CustomerID 1 - Exists in both, no change
   CustomerID 2 - Exists in both, email has changed
   CustomerID 3 - Exists in source only (new record - will INSERT)
================================================================ */
INSERT INTO TestData.Test.MRG_SCD1_Source
(CustomerID, FirstName, LastName, Email, Country)
VALUES
    (1, 'Alice',   'Smith',   'alice@example.com',     'Australia')    -- No change
    , (2, 'Bob',   'Jones',   'bob.new@example.com',   'Australia')    -- Email changed
    , (3, 'Carol', 'White',   'carol@example.com',     'New Zealand'); -- New record

/* ================================================================
   STEP 4 - Insert target data
   CustomerID 1 - Matches source exactly (no change expected)
   CustomerID 2 - Old email (change expected)
   CustomerID 4 - Exists in target only (will be hard deleted)
================================================================ */
INSERT INTO TestData.Test.MRG_SCD1_Target
(CustomerID, FirstName, LastName, Email, Country, WH_CreateDateTime_UTC, WH_ModifiedDateTime_UTC)
VALUES
    (1, 'Alice', 'Smith',  'alice@example.com',     'Australia', '2024-01-01', '2024-01-01')   -- No change
    , (2, 'Bob', 'Jones',  'bob.old@example.com',   'Australia', '2024-01-01', '2024-01-01')   -- Will update
    , (4, 'Dave', 'Brown', 'dave@example.com',      'Australia', '2024-01-01', '2024-01-01');  -- Will delete

/* ================================================================
   STEP 5 - Show state BEFORE merge
================================================================ */
PRINT '--- SOURCE TABLE (before merge) ---';
SELECT 'Source' AS TableName, * FROM TestData.Test.MRG_SCD1_Source ORDER BY CustomerID;

PRINT '--- TARGET TABLE (before merge) ---';
SELECT 'Target' AS TableName, * FROM TestData.Test.MRG_SCD1_Target ORDER BY CustomerID;

/* ================================================================
   STEP 6 - Insert merge configuration
================================================================ */
IF EXISTS (
    SELECT 1
    FROM SQLTools.Utility.MRG_DynamicMergeConfiguration
    WHERE MergeConfigurationName = 'Test_SCD1'
)
    UPDATE SQLTools.Utility.MRG_DynamicMergeConfiguration
    SET WH_IsDeleted = 1
    WHERE MergeConfigurationName = 'Test_SCD1';

INSERT INTO SQLTools.Utility.MRG_DynamicMergeConfiguration
(
    MergeConfigurationName
    , QualifiedSourceName
    , QualifiedTargetName
    , SCDType
    , MergeOnColumns
    , IgnoreColumns
    , DeleteIfNotMatchedBySource
    , IgnoreIdentityColumns
)
VALUES
(
    'Test_SCD1'
    , 'TestData.Test.MRG_SCD1_Source'
    , 'TestData.Test.MRG_SCD1_Target'
    , 'SCD1'
    , 'CustomerID'
    , 'WH_CreateDateTime_UTC,WH_ModifiedDateTime_UTC'
    , 1     -- Hard delete rows not matched by source
    , 1     -- Ignore identity columns
);

/* ================================================================
   STEP 7 - Run in debug mode first to review generated SQL
================================================================ */
PRINT '--- DEBUG MODE - Generated MERGE SQL ---';
USE SQLTools;
EXEC Utility.MRG_ExecuteMerge
    @MergeConfigurationName = 'Test_SCD1'
    , @DebugMode            = 1;

/* ================================================================
   STEP 8 - Execute the merge
================================================================ */
PRINT '--- EXECUTING MERGE ---';
EXEC Utility.MRG_ExecuteMerge
    @MergeConfigurationName = 'Test_SCD1'
    , @DebugMode            = 0;
USE TestData;

/* ================================================================
   STEP 9 - Show state AFTER merge
   Expected results:
     CustomerID 1 - Unchanged (WH_ModifiedDateTime_UTC same as before)
     CustomerID 2 - Email updated to bob.new@example.com, WH_ModifiedDateTime_UTC updated
     CustomerID 3 - New row inserted (Carol White)
     CustomerID 4 - Deleted (Dave Brown no longer exists)
================================================================ */
PRINT '--- TARGET TABLE (after merge) ---';
SELECT 'Target' AS TableName, * FROM TestData.Test.MRG_SCD1_Target ORDER BY CustomerID;