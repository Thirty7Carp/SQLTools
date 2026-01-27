SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[PublicHoliday](
	[DateKey_SK] [int] NOT NULL,
	[PublicHolidayType] [varchar](100) NULL,
	[PublicHolidayName] [varchar](100) NULL,
	[PublicHolidaySubstitute] [bit] NULL
) ON [PRIMARY]
GO