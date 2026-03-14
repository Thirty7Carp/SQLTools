CREATE PROCEDURE Utility.LNG_outputDatabaseExclusions
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ExclusionID,
        ServerName,
        DatabaseName,
        ExclusionReason,
        IsActive,
        CreatedDate,
        CreatedBy
    FROM Utility.LNG_DatabaseExclusions
    ORDER BY ServerName, DatabaseName;
END
GO