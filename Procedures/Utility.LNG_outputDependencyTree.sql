CREATE PROCEDURE Utility.LNG_outputDependencyTree
    @ServerName NVARCHAR(128) = NULL,  -- NULL defaults to current server
    @DatabaseName NVARCHAR(128),
    @SchemaName NVARCHAR(128),
    @ObjectName NVARCHAR(128),
    @Direction NVARCHAR(20) = 'Downstream',  -- 'Upstream' or 'Downstream'
    @MaxLevels INT = 5
AS
BEGIN
    SET NOCOUNT ON;
   
    IF @ServerName IS NULL
        SET @ServerName = @@SERVERNAME;
    
    ;WITH DependencyTree AS (
        -- Level 0: The root object
        SELECT 
            @ServerName AS ServerName,
            @DatabaseName AS DatabaseName,
            @SchemaName AS SchemaName,
            @ObjectName AS ObjectName,
            CAST('ROOT' AS NVARCHAR(60)) AS ObjectType,
            0 AS Level,
            CAST(@ServerName + '.' + @DatabaseName + '.' + @SchemaName + '.' + @ObjectName AS NVARCHAR(MAX)) AS TreePath,
            CAST('' AS NVARCHAR(10)) AS Prefix
        
        UNION ALL
        
        -- Recursive: Get dependencies
        SELECT 
            CASE 
                WHEN @Direction = 'Downstream' THEN od.SourceServer
                ELSE od.TargetServer
            END,
            CASE 
                WHEN @Direction = 'Downstream' THEN od.SourceDatabase
                ELSE od.TargetDatabase
            END,
            CASE 
                WHEN @Direction = 'Downstream' THEN od.SourceSchema
                ELSE od.TargetSchema
            END,
            CASE 
                WHEN @Direction = 'Downstream' THEN od.SourceObject
                ELSE od.TargetObject
            END,
            CAST(CASE 
                WHEN @Direction = 'Downstream' THEN od.SourceType
                ELSE od.TargetType
            END AS NVARCHAR(60)),
            dt.Level + 1,
            CAST(dt.TreePath + ' -> ' + 
                CASE 
                    WHEN @Direction = 'Downstream' THEN od.SourceServer + '.' + od.SourceDatabase + '.' + od.SourceSchema + '.' + od.SourceObject
                    ELSE od.TargetServer + '.' + od.TargetDatabase + '.' + od.TargetSchema + '.' + od.TargetObject
                END AS NVARCHAR(MAX)),
            CAST(REPLICATE('  ', dt.Level + 1) + '|--' AS NVARCHAR(10))
        FROM DependencyTree dt
        INNER JOIN Utility.LNG_ObjectDirectDependency od ON 
            (
                (@Direction = 'Downstream' AND 
                 dt.ServerName = od.TargetServer AND
                 dt.DatabaseName = od.TargetDatabase AND 
                 dt.SchemaName = od.TargetSchema AND 
                 dt.ObjectName = od.TargetObject)
                OR
                (@Direction = 'Upstream' AND 
                 dt.ServerName = od.SourceServer AND
                 dt.DatabaseName = od.SourceDatabase AND 
                 dt.SchemaName = od.SourceSchema AND 
                 dt.ObjectName = od.SourceObject)
            )
        WHERE dt.Level < @MaxLevels
            -- Prevent circular references
            AND dt.TreePath NOT LIKE '%' + 
                CASE 
                    WHEN @Direction = 'Downstream' THEN od.SourceServer + '.' + od.SourceDatabase + '.' + od.SourceSchema + '.' + od.SourceObject
                    ELSE od.TargetServer + '.' + od.TargetDatabase + '.' + od.TargetSchema + '.' + od.TargetObject
                END + '%'
    )
    SELECT 
        Level,
        Prefix + ServerName + '.' + DatabaseName + '.' + SchemaName + '.' + ObjectName AS DependencyTree,
        ObjectType,
        TreePath
    FROM DependencyTree
    ORDER BY TreePath
    OPTION (MAXRECURSION 0);
END
GO