CREATE PROCEDURE Utility.alterLineageObjectExclusionsRemove
    @ExclusionID BIGINT = NULL,
    @ServerName NVARCHAR(128) = NULL,
    @DatabaseName NVARCHAR(128) = NULL,
    @SchemaName NVARCHAR(128) = NULL,
    @ObjectName NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @ExclusionID IS NOT NULL
    BEGIN
        DELETE FROM Utility.LineageObjectExclusions WHERE ExclusionID = @ExclusionID;
        PRINT 'Exclusion removed (ID: ' + CAST(@ExclusionID AS VARCHAR(10)) + ')';
    END
    ELSE
    BEGIN
        DELETE FROM Utility.LineageObjectExclusions
        WHERE (ServerName = @ServerName OR (ServerName IS NULL AND @ServerName IS NULL))
            AND (DatabaseName = @DatabaseName OR (DatabaseName IS NULL AND @DatabaseName IS NULL))
            AND (SchemaName = @SchemaName OR (SchemaName IS NULL AND @SchemaName IS NULL))
            AND ObjectName = @ObjectName;
        
        PRINT 'Exclusion removed for: ' + ISNULL(@ServerName + '.', '') + ISNULL(@DatabaseName + '.', '') + 
              ISNULL(@SchemaName + '.', '') + @ObjectName;
    END
END
GO