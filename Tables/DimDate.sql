create TABLE [dbo].[DimDate](
    [DimDate_SK] [int] NOT NULL,
    [Date] [date] NULL,

    -- =========================
    -- Calendar fields
    -- =========================
    [CalendarYear] [int] NULL,
    [Month] [int] NULL,
    [Day] [int] NULL,
    [MonthName] [varchar](20) NULL,
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

    -- =========================
    -- Fiscal fields
    -- =========================
    [FiscalYear] [int] NULL,
    [FiscalHalf] [int] NULL,
    [FiscalQuarter] [int] NULL,
    [FiscalYearStart] [date] NULL,
    [FiscalHalfStart] [date] NULL,

    -- =========================
    -- Relative values
    -- =========================
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

    -- =========================
    -- Flags
    -- =========================
    [IsWeekend] [bit] NULL,
    [IsMTDToday] [bit] NULL,
    [IsMTDYesterday] [bit] NULL,
    [IsYTDToday] [bit] NULL,
    [IsYTDYesterday] [bit] NULL,
    [IsFiscalYTDToday] [bit] NULL,
    [IsFiscalYTDYesterday] [bit] NULL,

PRIMARY KEY CLUSTERED ([DimDate_SK] ASC)
) ON [PRIMARY];
