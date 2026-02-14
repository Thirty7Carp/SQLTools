create PROCEDURE dbo.reportLongPrint
    @sql VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check if input is valid
    IF @sql IS NULL OR LEN(@sql) = 0
    BEGIN
        PRINT 'No content to print'
        RETURN
    END
    
    -- Print in chunks to avoid truncation
    DECLARE @offset INT = 1
    DECLARE @chunkSize INT = 8000  -- Safe size under the 8192 limit
    
    WHILE @offset <= LEN(@sql)
    BEGIN
        PRINT SUBSTRING(@sql, @offset, @chunkSize)
        SET @offset = @offset + @chunkSize
    END
END