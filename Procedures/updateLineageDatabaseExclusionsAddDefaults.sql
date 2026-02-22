CREATE PROCEDURE Utility.updateLineageDatabaseExclusionsAddDefaults
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Add standard system databases
    INSERT INTO Utility.LineageDatabaseExclusions (DatabaseName, ExclusionReason)
    SELECT 'master', 'System database'
    WHERE NOT EXISTS (SELECT 1 FROM Utility.LineageDatabaseExclusions WHERE DatabaseName = 'master');
    
    INSERT INTO Utility.LineageDatabaseExclusions (DatabaseName, ExclusionReason)
    SELECT 'tempdb', 'System database'
    WHERE NOT EXISTS (SELECT 1 FROM Utility.LineageDatabaseExclusions WHERE DatabaseName = 'tempdb');
    
    INSERT INTO Utility.LineageDatabaseExclusions (DatabaseName, ExclusionReason)
    SELECT 'model', 'System database'
    WHERE NOT EXISTS (SELECT 1 FROM Utility.LineageDatabaseExclusions WHERE DatabaseName = 'model');
    
    INSERT INTO Utility.LineageDatabaseExclusions (DatabaseName, ExclusionReason)
    SELECT 'msdb', 'System database'
    WHERE NOT EXISTS (SELECT 1 FROM Utility.LineageDatabaseExclusions WHERE DatabaseName = 'msdb');
    
    PRINT 'Default database exclusions added (master, tempdb, model, msdb)';
END
GO