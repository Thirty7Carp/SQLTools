CREATE PROCEDURE Utility.outputLineageColumnUsage
    @ServerName NVARCHAR(128) = NULL,  -- NULL defaults to current server
    @DatabaseName NVARCHAR(128),
    @SchemaName NVARCHAR(128),
    @ObjectName NVARCHAR(128),
    @ColumnName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default to current server if not specified
    IF @ServerName IS NULL
        SET @ServerName = @@SERVERNAME;
    
    -- Objects that reference this column
    SELECT DISTINCT
        SourceServer,
        SourceDatabase,
        SourceSchema,
        SourceObject,
        SourceColumn,
        TransformationType
    FROM Utility.LineageColumnDependency
    WHERE TargetServer = @ServerName
        AND TargetDatabase = @DatabaseName
        AND TargetSchema = @SchemaName
        AND TargetObject = @ObjectName
        AND TargetColumn = @ColumnName
    ORDER BY SourceServer, SourceObject;
END
GO