CREATE PROCEDURE Utility.LNG_updateObjectExclusions_Add
    @ServerName NVARCHAR(128) = NULL,
    @DatabaseName NVARCHAR(128) = NULL,
    @SchemaName NVARCHAR(128) = NULL,
    @ObjectName NVARCHAR(128),
    @ExclusionReason NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO Utility.LNG_ObjectExclusions (ServerName, DatabaseName, SchemaName, ObjectName, ExclusionReason)
    VALUES (@ServerName, @DatabaseName, @SchemaName, @ObjectName, @ExclusionReason);
    
    PRINT 'Exclusion added for: ' + ISNULL(@ServerName + '.', '') + ISNULL(@DatabaseName + '.', '') + 
          ISNULL(@SchemaName + '.', '') + @ObjectName;
END
GO