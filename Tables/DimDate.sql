

SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO

DECLARE @sql NVARCHAR(MAX);

-- Base create table script
SET @sql = '
CREATE TABLE dbo.DimDate (
    DimDate_SK INT NOT NULL,
    Date DATE NULL,
    CalendarYear INT NULL,
    Month INT NULL,
    Day INT NULL,
    MonthName VARCHAR(20) NULL,
    MonthShortName VARCHAR(3) NULL,
    MonthAndCalendarYear VARCHAR(12) NULL,
    DayName VARCHAR(20) NULL,
    CalendarQuarter INT NULL,
    CalendarHalf INT NULL,
    MonthStart DATE NULL,
    CalendarQuarterStart DATE NULL,
    CalendarHalfStart DATE NULL,
    WeekStartMonday DATE NULL,
    WeekStartSunday DATE NULL,
    UnixStartOfDay BIGINT NULL,
    UnixEndOfDay BIGINT NULL,
    FiscalYear INT NULL,
    FiscalHalf INT NULL,
    FiscalQuarter INT NULL,
    FiscalYearStart DATE NULL,
    FiscalHalfStart DATE NULL,
    RelativeCalendarYear INT NULL,
    RelativeMonth INT NULL,
    RelativeDay INT NULL,
    RelativeCalendarQuarter INT NULL,
    RelativeCalendarHalf INT NULL,
    RelativeFiscalYear INT NULL,
    RelativeFiscalHalf INT NULL,
    RelativeFiscalQuarter INT NULL,
    RelativeWeekStartMonday INT NULL,
    RelativeWeekStartSunday INT NULL,
    isEndOfMonth bit NULL,
    IsWeekday BIT NULL,
    IsWeekend BIT NULL,
    IsMTDToday BIT NULL,
    IsMTDYesterday BIT NULL,
    IsYTDToday BIT NULL,
    IsYTDYesterday BIT NULL,
    IsFiscalYTDToday BIT NULL,
    IsFiscalYTDYesterday BIT NULL,
';

-- Add dynamic holiday columns
WITH HolidayFlags AS (
    SELECT 
        ph.PublicHolidayType,
        HasBusinessDays = CASE 
                             WHEN EXISTS (
                                 SELECT 1 
                                 FROM dbo.PublicHoliday ph2
                                 WHERE ph2.PublicHolidayType = ph.PublicHolidayType
                                   AND ph2.CountBusinessDays = 1
                             ) THEN 1 ELSE 0 
                          END
    FROM dbo.PublicHoliday ph
    GROUP BY ph.PublicHolidayType
)
SELECT @sql = @sql + '
    Holiday_' + PublicHolidayType + ' BIT NULL,' +
    CASE 
        WHEN HasBusinessDays = 1 
        THEN 'RelativeBusinessDays_Holiday_' + PublicHolidayType + ' INT NULL,' 
        ELSE '' 
    END
FROM HolidayFlags;





-- Remove trailing comma and close statement
SET @sql = LEFT(@sql, LEN(@sql)-1) + '
) ON [PRIMARY];
';

 EXEC sp_executesql @sql;

 -- Index on IsWeekend for faster filtering of weekdays vs weekends
CREATE NONCLUSTERED INDEX IX_DimDate_IsWeekend
ON dbo.DimDate (IsWeekend);

-- Index on Date for faster lookups and range queries
CREATE NONCLUSTERED INDEX IX_DimDate_Date
ON dbo.DimDate ([Date]);
