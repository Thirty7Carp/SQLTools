DECLARE @sql VARCHAR(MAX)
-- User pastes their SELECT statement here
SET @sql = 
    (
    SELECT ObjectDefinition 
    FROM dbo.ObjectDefinitions 
    WHERE objectName = 'reportObjectDataProfile'
    )

EXEC dbo.reportLongPrint @sql = @sql