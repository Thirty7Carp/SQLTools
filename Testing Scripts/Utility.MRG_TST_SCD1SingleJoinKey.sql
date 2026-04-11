/* =====================================================================
   Test Script - SQLTools.Utility.MRG_processSCD1
   -----------------------------------------------------------------------
   Creates test source and target tables in TestData.Test schema,
   inserts test data to cover all merge scenarios, then runs the merge
   and shows before/after results.

   Scenarios covered:
     1. Row exists in both, no change                          -> No action
     2. Row exists in both, varchar changed                    -> UPDATE
     3. Row exists in both, int changed                        -> UPDATE
     4. Row exists in both, NULL varchar becomes a value       -> UPDATE
     5. Row exists in both, NULL int becomes a value           -> UPDATE
     6. Row exists in source only (new record)                 -> INSERT
     7. Row exists in source with NULLs in varchar and int     -> INSERT
     8. Row exists in target only                              -> No action (DeleteIfNotMatchedBySource = 0)

   Merge key: CustomerID (int) + DateOfBirth (date)

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

GO

CREATE TABLE TestData.Test.MRG_SCD1_Source
(
    CustomerID      int             NOT NULL
    , DateOfBirth   date            NOT NULL
    , FirstName     varchar(100)    NULL
    , LastName      varchar(100)    NULL
    , Email         varchar(255)    NULL
    , Country       varchar(100)    NULL
    , Age           int             NULL
    , LoyaltyPoints int             NULL
);

GO

/* ================================================================
   STEP 2 - Create target table
================================================================ */
IF OBJECT_ID('TestData.Test.MRG_SCD1_Target', 'U') IS NOT NULL
    DROP TABLE TestData.Test.MRG_SCD1_Target;

GO

CREATE TABLE TestData.Test.MRG_SCD1_Target
(
    CustomerID              int             NOT NULL
    , DateOfBirth           date            NOT NULL
    , FirstName             varchar(100)    NULL
    , LastName              varchar(100)    NULL
    , Email                 varchar(255)    NULL
    , Country               varchar(100)    NULL
    , Age                   int             NULL
    , LoyaltyPoints         int             NULL
    , WH_CreateDateTime_UTC     datetime2   NOT NULL
    , WH_ModifiedDateTime_UTC   datetime2   NOT NULL
);

GO

/* ================================================================
   STEP 3 - Insert source data
   CustomerID 1  - No change
   CustomerID 2  - Email changed (varchar update)
   CustomerID 3  - Age changed (int update)
   CustomerID 4  - FirstName was NULL in target, now has a value
   CustomerID 5  - LoyaltyPoints was NULL in target, now has a value
   CustomerID 6  - New record, all values populated
   CustomerID 7  - New record, FirstName and Age are NULL
================================================================ */
INSERT INTO TestData.Test.MRG_SCD1_Source
(CustomerID, DateOfBirth, FirstName, LastName, Email, Country, Age, LoyaltyPoints)
VALUES
    (1, '1990-01-01', 'Alice',  'Smith',  'alice@example.com',    'Australia',   30,   100)   -- No change
    , (2, '1992-05-15', 'Bob',  'Jones',  'bob.new@example.com',  'Australia',   25,   200)   -- Email changed
    , (3, '1985-11-30', 'Carol','White',  'carol@example.com',    'New Zealand', 35,   300)   -- Age changed
    , (4, '1980-07-04', 'Dave', 'Brown',  'dave@example.com',     'Australia',   40,   400)   -- FirstName NULL -> value
    , (5, '1995-03-22', 'Eve',  'Taylor', 'eve@example.com',      'Australia',   28,   500)   -- LoyaltyPoints NULL -> value
    , (6, '1988-09-10', 'Frank','Wilson', 'frank@example.com',    'Australia',   45,   600)   -- New record
    , (7, '1993-12-25', NULL,   'Davies', NULL,                   'Australia',   NULL, NULL); -- New record with NULLs

/* ================================================================
   STEP 4 - Insert target data
   CustomerID 1  - Matches source exactly                      -> No action
   CustomerID 2  - Old email                                   -> UPDATE
   CustomerID 3  - Old age (28, source has 35)                 -> UPDATE
   CustomerID 4  - FirstName is NULL in target                 -> UPDATE
   CustomerID 5  - LoyaltyPoints is NULL in target             -> UPDATE
   CustomerID 8  - Exists in target only                       -> No action (DeleteIfNotMatchedBySource = 0)
================================================================ */
INSERT INTO TestData.Test.MRG_SCD1_Target
(CustomerID, DateOfBirth, FirstName, LastName, Email, Country, Age, LoyaltyPoints, WH_CreateDateTime_UTC, WH_ModifiedDateTime_UTC)
VALUES
    (1, '1990-01-01', 'Alice', 'Smith',  'alice@example.com',    'Australia',   30,   100,  '2024-01-01', '2024-01-01')  -- No change
    , (2, '1992-05-15', 'Bob', 'Jones',  'bob.old@example.com',  'Australia',   25,   200,  '2024-01-01', '2024-01-01')  -- Email will update
    , (3, '1985-11-30', NULL,  'White',  'carol@example.com',    'New Zealand', 28,   300,  '2024-01-01', '2024-01-01')  -- Age will update
    , (4, '1980-07-04', NULL,  'Brown',  NULL,                   'Australia',   40,   400,  '2024-01-01', '2024-01-01')  -- FirstName NULL -> value
    , (5, '1995-03-22', 'Eve', 'Taylor', 'eve@example.com',      'Australia',   28,   NULL, '2024-01-01', '2024-01-01')  -- LoyaltyPoints NULL -> value
    , (8, '1975-06-18', 'Grace','Hall',  'grace@example.com',    'Australia',   33,   700,  '2024-01-01', '2024-01-01'); -- No action, delete not enabled

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
    DELETE FROM SQLTools.Utility.MRG_DynamicMergeConfiguration
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
    , WH_CreateDateColumnName
    , WH_ModifiedDateColumnName
)
VALUES
(
    'Test_SCD1'
    , 'TestData.Test.MRG_SCD1_Source'
    , 'TestData.Test.MRG_SCD1_Target'
    , 'SCD1'
    , 'CustomerID,DateOfBirth'
    , NULL
    , 1
    , 1
    , NULL
    , NULL
);

/* ================================================================
   STEP 7 - Run in debug mode first to review generated SQL
================================================================ */
PRINT '--- DEBUG MODE - Generated MERGE SQL ---';
EXEC SQLTools.Utility.MRG_ExecuteMerge
    @MergeConfigurationName = 'Test_SCD1'
    , @DebugMode            = 1;

/* ================================================================
   STEP 8 - Execute the merge
================================================================ */
PRINT '--- EXECUTING MERGE ---';
EXEC SQLTools.Utility.MRG_ExecuteMerge
    @MergeConfigurationName = 'Test_SCD1'
    , @DebugMode            = 0;

/* ================================================================
   STEP 9 - Show state AFTER merge
   Expected results:
     CustomerID 1  - Unchanged (WH_ModifiedDateTime_UTC same as before)
     CustomerID 2  - Email updated to bob.new@example.com, WH_ModifiedDateTime_UTC updated
     CustomerID 3  - Age updated to 35, WH_ModifiedDateTime_UTC updated
     CustomerID 4  - FirstName updated from NULL to Dave, WH_ModifiedDateTime_UTC updated
     CustomerID 5  - LoyaltyPoints updated from NULL to 500, WH_ModifiedDateTime_UTC updated
     CustomerID 6  - New row inserted (Frank Wilson), WH_CreateDateTime_UTC and WH_ModifiedDateTime_UTC set
     CustomerID 7  - New row inserted (NULL FirstName, NULL Age), WH_CreateDateTime_UTC and WH_ModifiedDateTime_UTC set
     CustomerID 8  - Unchanged (DeleteIfNotMatchedBySource = 0)
================================================================ */
PRINT '--- TARGET TABLE (after merge) ---';
SELECT 'Target' AS TableName, * FROM TestData.Test.MRG_SCD1_Target ORDER BY CustomerID;