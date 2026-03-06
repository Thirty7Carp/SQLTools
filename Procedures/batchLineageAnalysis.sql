DECLARE @RowCount INT;

PRINT '============================================================';
PRINT 'Step 1: Loading Object List';
PRINT '============================================================';
EXEC Utility.loadLineageObjectList;
SELECT @RowCount = COUNT(*) FROM Utility.LineageObjectList;
PRINT 'Objects loaded into LineageObjectList: ' + CAST(@RowCount AS VARCHAR(20));

PRINT '============================================================';
PRINT 'Step 2: Loading Object Definitions';
PRINT '============================================================';
EXEC Utility.loadLineageObjectDefinitions;
SELECT @RowCount = COUNT(*) FROM Utility.LineageObjectDefinitions;
PRINT 'Objects loaded into LineageObjectDefinitions: ' + CAST(@RowCount AS VARCHAR(20));

PRINT '============================================================';
PRINT 'Step 3: Removing Comments';
PRINT '============================================================';
EXEC Utility.updateLineageObjectDefinitions_RemoveComments;


PRINT '============================================================';
PRINT 'Step 5: Removing Whitespace';
PRINT '============================================================';
EXEC Utility.updateLineageObjectDefinitions_RemoveWhitespace;

PRINT '============================================================';
PRINT 'Step 6: Loading Expression Dependencies';
PRINT '============================================================';
EXEC Utility.LoadLineageObjectExpressionDependency;
SELECT @RowCount = COUNT(*) FROM Utility.LineageObjectExpressionDependency;
PRINT 'Rows loaded into LineageObjectExpressionDependency: ' + CAST(@RowCount AS VARCHAR(20));

Declare @DependencyRowCount int

PRINT '============================================================';
PRINT 'Step 7: Loading Parsed Dependencies';
PRINT '============================================================';
EXEC Utility.LoadLineageObjectParsedDependency;
set @DependencyRowCount = (select count(1) from Utility.LineageObjectParsedDependency)
PRINT 'Rows loaded into LineageObjectExpressionDependency: ' + CAST(@DependencyRowCount AS VARCHAR(20));

declare @UpdatedRowCount int
declare @RowsRemoved int
PRINT '============================================================';
PRINT 'Step 8: Updating Parsed Dependencies';
PRINT '============================================================';
EXEC Utility.updateLineageObjectParsedDependency_ObjectCleanse;

set @UpdatedRowCount = (select count(1) from Utility.LineageObjectParsedDependency)
set @RowsRemoved = (select @DependencyRowCount - @UpdatedRowCount)
PRINT 'Rows removed from LineageObjectExpressionDependency: ' + CAST(@RowsRemoved AS VARCHAR(20));


PRINT '============================================================';
PRINT 'Pipeline Complete';
PRINT '============================================================';