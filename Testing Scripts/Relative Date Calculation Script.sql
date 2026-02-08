select 
	*
from dbo.DimDate
where 
	--dimdate_sk between 20220124 and 20220130
--	or dimdate_sk between 20291224 and 20291230
--	or 
	dimdate_sk between 20250101 and 20250210
	--or dimdate_sk = 99991231
	--or dimdate_sk = -1
	--or (CalendarYear = 2027 and day = 1)