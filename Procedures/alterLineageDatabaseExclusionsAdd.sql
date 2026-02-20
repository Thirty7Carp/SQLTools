CREATE PROCEDURE Utility.alterLineageDatabaseExclusionsAdd
    @ServerName NVARCHAR(128) = NULL,
    @DatabaseName NVARCHAR(128),
    @ExclusionReason NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO Utility.LineageDatabaseExclusions (ServerName, DatabaseName, ExclusionReason)
    VALUES (@ServerName, @DatabaseName, @ExclusionReason);
    
    PRINT 'Database exclusion added: ' + ISNULL(@ServerName + '.', '') + @DatabaseName;
END
GO