CREATE PROCEDURE Utility.updateLineageDatabaseExclusions_Remove
    @ExclusionID BIGINT = NULL,
    @ServerName NVARCHAR(128) = NULL,
    @DatabaseName NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @ExclusionID IS NOT NULL
    BEGIN
        DELETE FROM Utility.LineageDatabaseExclusions WHERE ExclusionID = @ExclusionID;
        PRINT 'Database exclusion removed (ID: ' + CAST(@ExclusionID AS VARCHAR(10)) + ')';
    END
    ELSE
    BEGIN
        DELETE FROM Utility.LineageDatabaseExclusions
        WHERE (ServerName = @ServerName OR (ServerName IS NULL AND @ServerName IS NULL))
            AND DatabaseName = @DatabaseName;
        
        PRINT 'Database exclusion removed: ' + ISNULL(@ServerName + '.', '') + @DatabaseName;
    END
END
GO