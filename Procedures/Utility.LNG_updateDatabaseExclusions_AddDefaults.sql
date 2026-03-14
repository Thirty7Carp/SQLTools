CREATE PROCEDURE Utility.LNG_updateDatabaseExclusions_AddDefaults
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Add standard system databases
    INSERT INTO Utility.LNG_DatabaseExclusions (DatabaseName, ExclusionReason)
    SELECT 'master', 'System database'
    WHERE NOT EXISTS (SELECT 1 FROM Utility.LNG_DatabaseExclusions WHERE DatabaseName = 'master');
    
    INSERT INTO Utility.LNG_DatabaseExclusions (DatabaseName, ExclusionReason)
    SELECT 'tempdb', 'System database'
    WHERE NOT EXISTS (SELECT 1 FROM Utility.LNG_DatabaseExclusions WHERE DatabaseName = 'tempdb');
    
    INSERT INTO Utility.LNG_DatabaseExclusions (DatabaseName, ExclusionReason)
    SELECT 'model', 'System database'
    WHERE NOT EXISTS (SELECT 1 FROM Utility.LNG_DatabaseExclusions WHERE DatabaseName = 'model');
    
    INSERT INTO Utility.LNG_DatabaseExclusions (DatabaseName, ExclusionReason)
    SELECT 'msdb', 'System database'
    WHERE NOT EXISTS (SELECT 1 FROM Utility.LNG_DatabaseExclusions WHERE DatabaseName = 'msdb');
    
    PRINT 'Default database exclusions added (master, tempdb, model, msdb)';
END
GO