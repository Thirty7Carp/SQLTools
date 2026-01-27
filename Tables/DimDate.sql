USE [Utility]
GO

/****** Object:  Table [dbo].[DimDate]    Script Date: 27/01/2026 7:12:58 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create TABLE [dbo].[DimDate](
	[DimDate_SK] [int] NOT NULL,
	[Date] [date] NULL,
	[CalendarYear] [int] NULL,
	[Month] [int] NULL,
	[Day] [int] NULL,
	[MonthName] [varchar](20) NULL,
	[MonthShortName] [varchar](3) NULL,
	[MonthAndCalendarYear] [varchar](12) NULL,
	[DayName] [varchar](20) NULL,
	[CalendarQuarter] [int] NULL,
	[CalendarHalf] [int] NULL,
	[MonthStart] [date] NULL,
	[CalendarQuarterStart] [date] NULL,
	[CalendarHalfStart] [date] NULL,
	[WeekStartMonday] [date] NULL,
	[WeekStartSunday] [date] NULL,
	[UnixStartOfDay] [bigint] NULL,
	[UnixEndOfDay] [bigint] NULL,
	[FiscalYear] [int] NULL,
	[FiscalHalf] [int] NULL,
	[FiscalQuarter] [int] NULL,
	[FiscalYearStart] [date] NULL,
	[FiscalHalfStart] [date] NULL,
	[RelativeCalendarYear] [int] NULL,
	[RelativeMonth] [int] NULL,
	[RelativeDay] [int] NULL,
	[RelativeCalendarQuarter] [int] NULL,
	[RelativeCalendarHalf] [int] NULL,
	[RelativeFiscalYear] [int] NULL,
	[RelativeFiscalHalf] [int] NULL,
	[RelativeFiscalQuarter] [int] NULL,
	[RelativeWeekStartMonday] [int] NULL,
	[RelativeWeekStartSunday] [int] NULL,
	[IsWeekday] [bit] NULL,
	[IsWeekend] [bit] NULL,
	[IsMTDToday] [bit] NULL,
	[IsMTDYesterday] [bit] NULL,
	[IsYTDToday] [bit] NULL,
	[IsYTDYesterday] [bit] NULL,
	[IsFiscalYTDToday] [bit] NULL,
	[IsFiscalYTDYesterday] [bit] NULL,
	[Holiday_AustraliaWA] [bit] NULL,
	[RelativeBusinessDays_Holiday_AustraliaWA] [int] NULL
) ON [PRIMARY]
GO


