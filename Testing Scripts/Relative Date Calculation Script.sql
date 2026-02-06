select 
	DayName
, DimDate_SK
, Holiday_AustraliaWA
, RelativeBusinessDays_Holiday_AustraliaWA
, Holiday_CountryStateFF
, RelativeBusinessDays_Holiday_CountryStateFF
from dbo.DimDate
where DimDate_SK >= 20200101 and DimDate_SK < 20340101