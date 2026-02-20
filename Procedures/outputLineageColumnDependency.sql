CREATE PROCEDURE Utility.outputLineageColumnDependency
    @ServerName NVARCHAR(128) = NULL,  -- NULL defaults to current server
    @DatabaseName NVARCHAR(128),
    @SchemaName NVARCHAR(128),
    @ObjectName NVARCHAR(128),
    @ColumnName NVARCHAR(128) = NULL  -- NULL = all columns
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default to current server if not specified
    IF @ServerName IS NULL
        SET @ServerName = @@SERVERNAME;
    
    IF @ColumnName IS NULL
    BEGIN
        -- Show all columns for the object
        SELECT 
            SourceServer,
            SourceDatabase,
            SourceSchema,
            SourceObject,
            SourceColumn,
            TargetServer,
            TargetDatabase,
            TargetSchema,
            TargetObject,
            TargetColumn,
            TransformationType
        FROM Utility.LineageColumnDependency
        WHERE SourceServer = @ServerName
            AND SourceDatabase = @DatabaseName
            AND SourceSchema = @SchemaName
            AND SourceObject = @ObjectName
        ORDER BY SourceColumn, TargetServer, TargetObject, TargetColumn;
    END
    ELSE
    BEGIN
        -- Show lineage for specific column
        SELECT 
            SourceServer,
            SourceDatabase,
            SourceSchema,
            SourceObject,
            SourceColumn,
            TargetServer,
            TargetDatabase,
            TargetSchema,
            TargetObject,
            TargetColumn,
            TransformationType
        FROM Utility.LineageColumnDependency
        WHERE SourceServer = @ServerName
            AND SourceDatabase = @DatabaseName
            AND SourceSchema = @SchemaName
            AND SourceObject = @ObjectName
            AND SourceColumn = @ColumnName
        ORDER BY TargetServer, TargetObject, TargetColumn;
    END
END
GO