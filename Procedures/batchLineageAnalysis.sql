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
PRINT 'Step 4: Removing String Literals';
PRINT '============================================================';
EXEC Utility.updateLineageObjectDefinitions_RemoveStringLiterals;

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

PRINT '============================================================';
PRINT 'Step 7: Loading Parsed Dependencies';
PRINT '============================================================';
EXEC Utility.LoadLineageObjectParsedDependency;
SELECT @RowCount = COUNT(*) FROM Utility.LineageObjectParsedDependency;
PRINT 'Rows loaded into LineageObjectParsedDependency: ' + CAST(@RowCount AS VARCHAR(20));

PRINT '============================================================';
PRINT 'Pipeline Complete';
PRINT '============================================================';