DECLARE @sql VARCHAR(MAX)
SET @sql = 
    (
    SELECT
        ObjectDefinition
    FROM
        dbo.ObjectDefinitions
    WHERE
        objectName = 'usp_ComplexQueryParserTest'
    )

-- Print in chunks to avoid truncation
DECLARE @offset INT = 1
DECLARE @chunkSize INT = 8000  -- Safe size under the 8192 limit

WHILE @offset <= LEN(@sql)
BEGIN
    PRINT SUBSTRING(@sql, @offset, @chunkSize)
    SET @offset = @offset + @chunkSize
END