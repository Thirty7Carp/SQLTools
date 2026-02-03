select
	*
from
	dbo.DimDate
where
	Date = '2026-01-24'
	or DaTe = '2025-12-26'
	or date = '2026-01-01'
	or date = '0001-01-01'
	or date = '9999-12-31'
	or date = '2025-06-30'
	or date = '2025-07-01'
	or DimDate_SK between 20250123 and 20250128
order by 
	date
