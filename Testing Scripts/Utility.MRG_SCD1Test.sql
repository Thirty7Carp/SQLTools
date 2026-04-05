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
     8. Row exists in target only                              -> Hard DELETE

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
    , FirstName     varchar(100)    NULL
    , LastName      varchar(100)    NULL
    , Email         varchar(255)    NULL
    , Country       varchar(100)    NOT NULL
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
    CustomerID      int             NOT NULL
    , FirstName     varchar(100)    NULL
    , LastName      varchar(100)    NULL
    , Email         varchar(255)    NULL
    , Country       varchar(100)    NOT NULL
    , Age           int             NULL
    , LoyaltyPoints int             NULL
    , WH_CreateDateTime_UTC   datetime2       NOT NULL
    , WH_ModifiedDateTime_UTC      datetime2       NOT NULL
);

/* ================================================================
   STEP 3 - Insert source data
   CustomerID 1  - No change
   CustomerID 2  - Email changed (varchar update)
   CustomerID 3  - Age changed (int update)
   CustomerID 4  - FirstName was NULL, now has a value (NULL varchar -> value)
   CustomerID 5  - LoyaltyPoints was NULL, now has a value (NULL int -> value)
   CustomerID 6  - New record, all values populated
   CustomerID 7  - New record, FirstName and Age are NULL
================================================================ */
INSERT INTO TestData.Test.MRG_SCD1_Source
(CustomerID, FirstName, LastName, Email, Country, Age, LoyaltyPoints)
VALUES
    (1, 'Alice',   'Smith',   'alice@example.com',     'Australia',   30,   100)   -- No change
    , (2, 'Bob',   'Jones',   'bob.new@example.com',   'Australia',   25,   200)   -- Email changed
    , (3, 'Carol', 'White',   'carol@example.com',     'New Zealand', 35,   300)   -- Age changed
    , (4, NULL, NULL, NULL,      'Australia',   40,   400)   -- FirstName NULL -> value
    , (5, 'Eve',   'Taylor',  'eve@example.com',       'Australia',   28,   500)   -- LoyaltyPoints NULL -> value
    , (6, 'Frank', 'Wilson',  'frank@example.com',     'Australia',   45,   600)   -- New record
    , (7, NULL,    'Davies',  NULL,                    'Australia',   NULL, NULL); -- New record with NULLs

/* ================================================================
   STEP 4 - Insert target data
   CustomerID 1  - Matches source exactly
   CustomerID 2  - Old email
   CustomerID 3  - Old age (28 -> 35)
   CustomerID 4  - FirstName is NULL in target
   CustomerID 5  - LoyaltyPoints is NULL in target
   CustomerID 8  - Exists in target only (will be hard deleted)
================================================================ */
INSERT INTO TestData.Test.MRG_SCD1_Target
(CustomerID, FirstName, LastName, Email, Country, Age, LoyaltyPoints, WH_CreateDateTime_UTC, WH_ModifiedDateTime_UTC)
VALUES
    (1, 'Alice',  'Smith',  'alice@example.com',     'Australia',   30,   100,  '2024-01-01', '2024-01-01')  -- No change
    , (2, 'Bob',  'Jones',  'bob.old@example.com',   'Australia',   25,   200,  '2024-01-01', '2024-01-01')  -- Email will update
    , (3, 'Carol','White',  'carol@example.com',     'New Zealand', 28,   300,  '2024-01-01', '2024-01-01')  -- Age will update
    , (4, NULL,   'Brown',  NULL,      'Australia',   40,   400,  '2024-01-01', '2024-01-01')  -- FirstName NULL -> value
    , (5, 'Eve',  'Taylor', 'eve@example.com',       'Australia',   28,   NULL, '2024-01-01', '2024-01-01')  -- LoyaltyPoints NULL -> value
    , (8, 'Grace','Hall',   'grace@example.com',     'Australia',   33,   700,  '2024-01-01', '2024-01-01'); -- Will delete

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
    Delete from SQLTools.Utility.MRG_DynamicMergeConfiguration
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
    , 'CustomerID'
    , NULL
    , 0             -- Hard delete rows not matched by source
    , 1             -- Ignore identity columns
    , NULL -- Override default WH_CreateDateColumnName
    , NULL    -- Override default WH_ModifiedDateColumnName
);

select * from SQLTools.Utility.MRG_DynamicMergeConfiguration
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
     CustomerID 1  - Unchanged (DW_WH_ModifiedDateTime_UTC same as before)
     CustomerID 2  - Email updated to bob.new@example.com, DW_WH_ModifiedDateTime_UTC updated
     CustomerID 3  - Age updated to 35, DW_WH_ModifiedDateTime_UTC updated
     CustomerID 4  - FirstName updated from NULL to 'Dave', DW_WH_ModifiedDateTime_UTC updated
     CustomerID 5  - LoyaltyPoints updated from NULL to 500, DW_WH_ModifiedDateTime_UTC updated
     CustomerID 6  - New row inserted (Frank Wilson), WH_CreateDateTime_UTC and DW_WH_ModifiedDateTime_UTC set
     CustomerID 7  - New row inserted (NULL FirstName, NULL Email, NULL Age, NULL LoyaltyPoints)
     CustomerID 8  - Deleted (Grace Hall no longer in source)
================================================================ */
PRINT '--- TARGET TABLE (after merge) ---';
SELECT 'Target' AS TableName, * FROM TestData.Test.MRG_SCD1_Target ORDER BY CustomerID;