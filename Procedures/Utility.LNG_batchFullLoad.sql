--TRUNCATE TABLE Utility.LNG_ObjectParsedDependency ;

DECLARE @RowCount INT;
PRINT '============================================================';
PRINT 'Step 0: Loading Default Database Exclusions';
PRINT '============================================================';
EXEC Utility.LNG_updateDatabaseExclusions_AddDefaults
SELECT @RowCount = COUNT(*) FROM Utility.LNG_DatabaseExclusions;
PRINT 'Objects loaded into DatabaseExclusions: ' + CAST(@RowCount AS VARCHAR(20));


PRINT '============================================================';
PRINT 'Step 1: Loading Object List';
PRINT '============================================================';
EXEC Utility.LNG_loadObjectList;
SELECT @RowCount = COUNT(*) FROM Utility.LNG_ObjectList;
PRINT 'Objects loaded into LineageObjectList: ' + CAST(@RowCount AS VARCHAR(20));

PRINT '============================================================';
PRINT 'Step 2: Loading Object Definitions';
PRINT '============================================================';
EXEC Utility.LNG_loadObjectDefinitions;
SELECT @RowCount = COUNT(*) FROM Utility.LNG_ObjectDefinitions;
PRINT 'Objects loaded into LineageObjectDefinitions: ' + CAST(@RowCount AS VARCHAR(20));

PRINT '============================================================';
PRINT 'Step 3: Removing Comments';
PRINT '============================================================';
EXEC Utility.LNG_updateObjectDefinitions_RemoveComments;


PRINT '============================================================';
PRINT 'Step 4: Removing Whitespace';
PRINT '============================================================';
EXEC Utility.LNG_updateObjectDefinitions_RemoveWhitespace;

PRINT '============================================================';
PRINT 'Step 5: Loading Expression Dependencies';
PRINT '============================================================';
EXEC Utility.LNG_loadObjectExpressionDependency;
SELECT @RowCount = COUNT(*) FROM Utility.LNG_ObjectExpressionDependency;
PRINT 'Rows loaded into LineageObjectExpressionDependency: ' + CAST(@RowCount AS VARCHAR(20));

Declare @DependencyRowCount int

PRINT '============================================================';
PRINT 'Step 6: Loading Parsed Dependencies';
PRINT '============================================================';
EXEC Utility.LNG_loadObjectParsedDependency;
set @DependencyRowCount = (select count(1) from Utility.LNG_ObjectParsedDependency)
PRINT 'Rows loaded into LineageObjectExpressionDependency: ' + CAST(@DependencyRowCount AS VARCHAR(20));

declare @UpdatedRowCount int
declare @RowsRemoved int
PRINT '============================================================';
PRINT 'Step 7: Updating Parsed Dependencies';
PRINT '============================================================';

EXEC Utility.LNG_updateObjectParsedDependency_ObjectCleanse;
set @UpdatedRowCount = (select count(1) from Utility.LNG_ObjectParsedDependency)
set @RowsRemoved = (select @DependencyRowCount - @UpdatedRowCount)
PRINT 'Rows removed from LineageObjectExpressionDependency: ' + CAST(@RowsRemoved AS VARCHAR(20));


PRINT '============================================================';
PRINT 'Step 8: Distinct Direct Dependencies';
PRINT '============================================================';
EXEC Utility.LNG_loadObjectDirectDependency
set @RowCount = (select count(1) from Utility.LNG_ObjectDirectDependency)
PRINT 'Rows loaded into LNG_ObjectDirectDependency: ' + CAST(@RowCount AS VARCHAR(20));


PRINT '============================================================';
PRINT 'Step 9: Extended Dependencies';
PRINT '============================================================';
EXEC Utility.LNG_loadObjectExtendedDependency
set @RowCount = (select count(1) from Utility.LNG_ObjectExtendedDependency)
PRINT 'Rows loaded into LNG_ObjectExtendedDependency: ' + CAST(@RowCount AS VARCHAR(20));


PRINT '============================================================';
PRINT 'Pipeline Complete';
PRINT '============================================================';