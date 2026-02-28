CREATE  PROCEDURE Utility.outputLineageObjectExclusions
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ExclusionID,
        ServerName,
        DatabaseName,
        SchemaName,
        ObjectName,
        ExclusionReason,
        IsActive,
        CreatedDate,
        CreatedBy
    FROM Utility.LineageObjectExclusions
    ORDER BY ServerName, DatabaseName, SchemaName, ObjectName;
END
GO