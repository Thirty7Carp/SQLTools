CREATE PROCEDURE Utility.outputLineageDatabaseExclusions
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
    FROM Utility.LineageDatabaseExclusions
    ORDER BY ServerName, DatabaseName;
END
GO