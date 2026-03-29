IF OBJECT_ID('Utility.LNG_outputObjectDependency', 'P') IS NOT NULL
    DROP PROCEDURE Utility.LNG_outputObjectDependency;

GO

CREATE PROCEDURE Utility.LNG_outputObjectDependency
    @ServerName NVARCHAR(128) = NULL,  -- NULL defaults to current server
    @DatabaseName NVARCHAR(128),
    @SchemaName NVARCHAR(128),
    @ObjectName NVARCHAR(128),
    @Direction NVARCHAR(20) = 'Both'  -- 'Upstream', 'Downstream', or 'Both'
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @ServerName IS NULL
        SET @ServerName = @@SERVERNAME;
    
    IF @Direction IN ('Downstream', 'Both')
    BEGIN
        PRINT '=== DOWNSTREAM DEPENDENCIES (What depends on this object) ===';
        SELECT 
            LineageLevel,
            DependentServer,
            DependentDatabase,
            DependentSchema,
            DependentObject,
            DependentObjectType,
            LineagePath
        FROM Utility.LNG_ObjectExtendedDependency
        WHERE RootServer = @ServerName
            AND RootDatabase = @DatabaseName
            AND RootSchema = @SchemaName
            AND RootObject = @ObjectName
            AND LineageDirection = 'Downstream'
        ORDER BY LineageLevel, DependentServer, DependentDatabase, DependentSchema, DependentObject;
    END
    
    IF @Direction IN ('Upstream', 'Both')
    BEGIN
        PRINT '=== UPSTREAM DEPENDENCIES (What this object depends on) ===';
        SELECT 
            LineageLevel,
            DependentServer,
            DependentDatabase,
            DependentSchema,
            DependentObject,
            DependentObjectType,
            LineagePath
        FROM Utility.LNG_ObjectExtendedDependency
        WHERE RootServer = @ServerName
            AND RootDatabase = @DatabaseName
            AND RootSchema = @SchemaName
            AND RootObject = @ObjectName
            AND LineageDirection = 'Upstream'
        ORDER BY LineageLevel, DependentServer, DependentDatabase, DependentSchema, DependentObject;
    END
END
GO