select 
	DayName
, DimDate_SK
, Holiday_AustraliaWA
, RelativeBusinessDays_Holiday_AustraliaWA
, Holiday_CountryStateFF
, RelativeBusinessDays_Holiday_CountryStateFF
from dbo.DimDate
where dimdate_sk between 20220124 and 20220130
	or dimdate_sk between 20291224 and 20291230
	or dimdate_sk between 20260205 and 20260210

select
	*
from
	dbo.DimDate
where
	IsWeekday = 1
	and date < '2026-01-01'
	and Holiday_AustraliaWA = 1