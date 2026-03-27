SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Common].[DT_PublicHoliday](
	[DimDate_SK] [int] NOT NULL,
	[PublicHolidayType] [varchar](100) NOT NULL,
	[PublicHolidayName] [varchar](100) NOT NULL,
	[PublicHolidaySubstitute] [bit] NOT NULL CONSTRAINT DF_DT_DimDate_PublicHolidaySubstitute DEFAULT (0),
	[CountBusinessDays] bit NOT NULL CONSTRAINT DF_DT_DimDate_CountBusinessDays DEFAULT (0)
) ON [PRIMARY]
GO



