IF OBJECT_ID('Utility.LNG_updateDatabaseExclusions_Add', 'P') IS NOT NULL
    DROP PROCEDURE Utility.LNG_updateDatabaseExclusions_Add;

GO

CREATE PROCEDURE Utility.LNG_updateDatabaseExclusions_Add
    @ServerName NVARCHAR(128) = NULL,
    @DatabaseName NVARCHAR(128),
    @ExclusionReason NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO Utility.LNG_DatabaseExclusions (ServerName, DatabaseName, ExclusionReason)
    VALUES (@ServerName, @DatabaseName, @ExclusionReason);
    
    PRINT 'Database exclusion added: ' + ISNULL(@ServerName + '.', '') + @DatabaseName;
END
GO