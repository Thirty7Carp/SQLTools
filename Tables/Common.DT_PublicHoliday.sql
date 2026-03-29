IF OBJECT_ID(N'Common.DT_PublicHoliday', N'U') IS NULL

BEGIN

CREATE TABLE [Common].[DT_PublicHoliday](
	[DimDate_SK] [int] NOT NULL,
	[PublicHolidayType] [varchar](100) NOT NULL,
	[PublicHolidayName] [varchar](100) NOT NULL,
	[PublicHolidaySubstitute] [bit] NOT NULL CONSTRAINT DF_DT_DimDate_PublicHolidaySubstitute DEFAULT (0),
	[CountBusinessDays] bit NOT NULL CONSTRAINT DF_DT_DimDate_CountBusinessDays DEFAULT (0)
) ON [PRIMARY]

END

