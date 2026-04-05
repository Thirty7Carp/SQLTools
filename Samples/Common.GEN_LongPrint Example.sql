DECLARE @sql VARCHAR(MAX)
-- User pastes their SELECT statement here
SET @sql = 
    (
   
   --[YOUR QUERY THAT RETURNS ONE ROW HERE]
   select 1

    )

EXEC Utility.GEN_outputLongPrint @sql = @sql