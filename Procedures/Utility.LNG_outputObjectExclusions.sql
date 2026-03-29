IF OBJECT_ID('Utility.LNG_outputObjectExclusions', 'P') IS NOT NULL
    DROP PROCEDURE Utility.LNG_outputObjectExclusions;

GO

CREATE  PROCEDURE Utility.LNG_outputObjectExclusions
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
    FROM Utility.LNG_ObjectExclusions
    ORDER BY ServerName, DatabaseName, SchemaName, ObjectName;
END
GO