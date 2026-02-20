CREATE PROCEDURE Utility.batchLineageAnalysis
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @ObjectCount INT, @DependencyCount INT, @LineageCount INT;
    
    PRINT '=== STARTING COMPLETE LINEAGE ANALYSIS ===';
    PRINT 'Start Time: ' + CONVERT(VARCHAR(30), @StartTime, 121);
    PRINT '';
    
    -- Step 1: Capture all objects
    PRINT 'Step 1: Capturing all database objects...';
    EXEC Utility.loadLineageObjectList;
    SELECT @ObjectCount = COUNT(*) FROM Utility.LineageObjectList;
    PRINT 'Objects captured: ' + CAST(@ObjectCount AS VARCHAR(10));
    PRINT '';
    
    -- Step 2: Capture all dependencies
    PRINT 'Step 2: Capturing all dependencies...';
    EXEC Utility.loadLineageObjectDirectDependency;
    SELECT @DependencyCount = COUNT(*) FROM Utility.LineageObjectDirectDependency;
    PRINT 'Dependencies captured: ' + CAST(@DependencyCount AS VARCHAR(10));
    PRINT '';
    
    -- Step 3: Build complete lineage
    PRINT 'Step 3: Building complete lineage...';
    EXEC Utility.updateLineageObjectExtendedDependency @MaxLevels = 10;
    SELECT @LineageCount = COUNT(*) FROM Utility.LineageObjectExtendedDependency;
    PRINT 'Lineage paths built: ' + CAST(@LineageCount AS VARCHAR(10));
    PRINT '';
    
    -- Step 4: Capture column-level lineage
    PRINT 'Step 4: Capturing column-level lineage...';
    EXEC Utility.loadLineageColumnDependency;
    DECLARE @ColumnLineageCount INT;
    SELECT @ColumnLineageCount = COUNT(*) FROM Utility.LineageColumnDependency;
    PRINT 'Column lineage captured: ' + CAST(@ColumnLineageCount AS VARCHAR(10));
    PRINT '';
    
    -- Summary statistics
    PRINT '=== SUMMARY ===';
    PRINT 'Total Objects: ' + CAST(@ObjectCount AS VARCHAR(10));
    PRINT 'Total Direct Dependencies: ' + CAST(@DependencyCount AS VARCHAR(10));
    PRINT 'Total Lineage Paths: ' + CAST(@LineageCount AS VARCHAR(10));
    PRINT 'Total Column Lineage: ' + CAST(@ColumnLineageCount AS VARCHAR(10));
    PRINT 'Execution Time: ' + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS VARCHAR(10)) + ' seconds';
    PRINT '';
    
    -- Object type breakdown
    PRINT '=== OBJECT TYPE BREAKDOWN ===';
    SELECT ObjectTypeName, COUNT(*) AS Count
    FROM Utility.LineageObjectList
    GROUP BY ObjectTypeName
    ORDER BY COUNT(*) DESC;
    
    -- Database breakdown
    PRINT '';
    PRINT '=== DATABASE BREAKDOWN ===';
    SELECT DatabaseName, COUNT(*) AS ObjectCount
    FROM Utility.LineageObjectList
    GROUP BY DatabaseName
    ORDER BY COUNT(*) DESC;
END
GO
