
CREATE  PROCEDURE Utility.outputLineageImpactAnalysis
    @ServerName NVARCHAR(128) = NULL,  -- NULL defaults to current server
    @DatabaseName NVARCHAR(128),
    @SchemaName NVARCHAR(128),
    @ObjectName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default to current server if not specified
    IF @ServerName IS NULL
        SET @ServerName = @@SERVERNAME;
    
    PRINT '=== IMPACT ANALYSIS: ' + @ServerName + '.' + @DatabaseName + '.' + @SchemaName + '.' + @ObjectName + ' ===';
    
    SELECT 
        LineageLevel,
        COUNT(DISTINCT DependentServer + '.' + DependentDatabase + '.' + DependentSchema + '.' + DependentObject) AS AffectedObjectCount,
        STRING_AGG(DependentServer + '.' + DependentDatabase + '.' + DependentSchema + '.' + DependentObject, ', ') WITHIN GROUP (ORDER BY DependentServer, DependentDatabase, DependentSchema, DependentObject) AS AffectedObjects
    FROM Utility.LineageObjectExtendedDependency
    WHERE RootServer = @ServerName
        AND RootDatabase = @DatabaseName
        AND RootSchema = @SchemaName
        AND RootObject = @ObjectName
        AND LineageDirection = 'Downstream'
    GROUP BY LineageLevel
    ORDER BY LineageLevel;
    
    -- Summary
    SELECT 
        COUNT(DISTINCT DependentServer + '.' + DependentDatabase + '.' + DependentSchema + '.' + DependentObject) AS TotalAffectedObjects,
        MAX(LineageLevel) AS MaxDependencyDepth
    FROM Utility.LineageObjectExtendedDependency
    WHERE RootServer = @ServerName
        AND RootDatabase = @DatabaseName
        AND RootSchema = @SchemaName
        AND RootObject = @ObjectName
        AND LineageDirection = 'Downstream';
END
GO