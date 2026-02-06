/* 
Run this immediately after midnight each night to update all the relative values.

Make sure to:
    - update the @FiscalYearStartMMDD, July 1 (0701) was set because Australia.
    - update the @UTCOffsetMinutes to reflect your local timezone, 480 was set because Perth.
    - Updated the @MaximumDate if you need dates after 2099 for some reason.
*/

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

alter PROCEDURE [dbo].[loadDimDate]
    @FiscalYearStartMMDD CHAR(4) = '0701',
    @MinimumDate date = '1800-01-01',
    @MaximumDate DATE = '2099-12-31',
    @UTCOffsetMinutes int = 480
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TodayDate DATE = CAST(Dateadd(n, @UTCOffsetMinutes, GetUTCDATE()) AS DATE);
    DECLARE @YesterdayDate DATE = DATEADD(DAY, -1, @TodayDate);

    -- Compute the current fiscal year start once, based on today's date
    DECLARE @CurrentFiscalYearStart DATE = CAST(
        CAST(
            CASE 
                WHEN FORMAT(@TodayDate, 'MMdd') >= @FiscalYearStartMMDD 
                     THEN YEAR(@TodayDate) 
                ELSE YEAR(@TodayDate) - 1 
            END AS VARCHAR(4)
        ) + @FiscalYearStartMMDD 
    AS DATE);

    TRUNCATE TABLE dbo.DimDate;

    ;WITH DateSequence AS (
        SELECT CAST(@MinimumDate AS DATE) AS TheDate
        UNION ALL
        SELECT DATEADD(DAY, 1, TheDate)
        FROM DateSequence
        WHERE TheDate <= @MaximumDate
    )
    INSERT INTO dbo.DimDate (
        DimDate_SK, Date,

        -- Calendar fields
        CalendarYear, Month, Day, MonthName, MonthShortName, MonthAndCalendarYear, DayName,
        CalendarQuarter, CalendarHalf,
        MonthStart, CalendarQuarterStart, CalendarHalfStart,
        WeekStartMonday, WeekStartSunday,
        UnixStartOfDay, UnixEndOfDay,

        -- Fiscal fields
        FiscalYear, FiscalHalf, FiscalQuarter,
        FiscalYearStart, FiscalHalfStart,

        -- Relative values
        RelativeCalendarYear, RelativeMonth, RelativeDay,
        RelativeCalendarQuarter, RelativeCalendarHalf,
        RelativeFiscalYear, RelativeFiscalHalf, RelativeFiscalQuarter,
        RelativeWeekStartMonday, RelativeWeekStartSunday,

        -- Flags
        IsWeekday, IsWeekend,
        IsMTDToday, IsMTDYesterday,
        IsYTDToday, IsYTDYesterday,
        IsFiscalYTDToday, IsFiscalYTDYesterday
    )
    SELECT 
        DimDate_SK       = CONVERT(INT, FORMAT(TheDate, 'yyyyMMdd')),
        Date             = TheDate,

        -- Calendar fields
        CalendarYear     = YEAR(TheDate),
        Month            = MONTH(TheDate),
        Day              = DAY(TheDate),
        MonthName        = DATENAME(MONTH, TheDate),
        MonthShortName   = LEFT(DATENAME(MONTH, TheDate), 3),
        MonthAndCalendarYear = LEFT(DATENAME(MONTH, TheDate), 3) + ' ' + CAST(YEAR(TheDate) AS VARCHAR(4)),
        DayName          = DATENAME(WEEKDAY, TheDate),
        CalendarQuarter  = DATEPART(QUARTER, TheDate),
        CalendarHalf     = CASE WHEN MONTH(TheDate) <= 6 THEN 1 ELSE 2 END,
        MonthStart       = DATEADD(MONTH, DATEDIFF(MONTH, 0, TheDate), 0),
        CalendarQuarterStart = DATEADD(QUARTER, DATEDIFF(QUARTER, 0, TheDate), 0),
        CalendarHalfStart    = DATEADD(MONTH, (DATEDIFF(MONTH, 0, TheDate) / 6) * 6, 0),
        WeekStartMonday  = DATEADD(DAY, -((DATEPART(WEEKDAY, TheDate) + @@DATEFIRST - 2) % 7), TheDate),
        WeekStartSunday  = DATEADD(DAY, -DATEPART(WEEKDAY, TheDate) + 1, TheDate),
        UnixStartOfDay   = CAST(DATEDIFF(DAY, '1970-01-01', TheDate) AS BIGINT) * 86400,
        UnixEndOfDay     = CAST(DATEDIFF(DAY, '1970-01-01', TheDate) AS BIGINT) * 86400 + 86399,

        -- Fiscal fields
        FiscalYear       = CASE 
                              WHEN FORMAT(TheDate, 'MMdd') >= @FiscalYearStartMMDD 
                                   THEN YEAR(TheDate) + 1 
                              ELSE YEAR(TheDate) 
                           END,
        FiscalHalf       = CASE 
                              WHEN ((MONTH(TheDate) - CAST(LEFT(@FiscalYearStartMMDD,2) AS INT) + 12) % 12) < 6 
                                   THEN 1 ELSE 2 
                           END,
        FiscalQuarter    = ((MONTH(TheDate) - CAST(LEFT(@FiscalYearStartMMDD,2) AS INT) + 12) % 12) / 3 + 1,
        FiscalYearStart  = CAST(
                              CAST(
                                  CASE 
                                      WHEN FORMAT(TheDate, 'MMdd') >= @FiscalYearStartMMDD 
                                           THEN YEAR(TheDate) 
                                      ELSE YEAR(TheDate) - 1 
                                  END AS VARCHAR(4)
                              ) + @FiscalYearStartMMDD 
                          AS DATE),
        FiscalHalfStart  = DATEADD(MONTH, ((CASE 
                                               WHEN ((MONTH(TheDate) - CAST(LEFT(@FiscalYearStartMMDD,2) AS INT) + 12) % 12) < 6 
                                                    THEN 1 ELSE 2 END) - 1) * 6, 
                                   CAST(
                                       CAST(
                                           CASE 
                                               WHEN FORMAT(TheDate, 'MMdd') >= @FiscalYearStartMMDD 
                                                    THEN YEAR(TheDate) 
                                               ELSE YEAR(TheDate) - 1 
                                           END AS VARCHAR(4)
                                       ) + @FiscalYearStartMMDD 
                                   AS DATE)),

        -- Relative values
        RelativeCalendarYear     = YEAR(TheDate) - YEAR(@TodayDate),
        RelativeMonth            = (YEAR(TheDate) * 12 + MONTH(TheDate)) - (YEAR(@TodayDate) * 12 + MONTH(@TodayDate)),
        RelativeDay              = DATEDIFF(DAY, @TodayDate, TheDate),
        RelativeCalendarQuarter  = DATEPART(QUARTER, TheDate) - DATEPART(QUARTER, @TodayDate) + ((YEAR(TheDate) - YEAR(@TodayDate)) * 4),
        RelativeCalendarHalf     = (CASE WHEN MONTH(TheDate) <= 6 THEN 1 ELSE 2 END)
                                   - (CASE WHEN MONTH(@TodayDate) <= 6 THEN 1 ELSE 2 END)
                                   + ((YEAR(TheDate) - YEAR(@TodayDate)) * 2),
        RelativeFiscalYear = 
            (CASE WHEN FORMAT(TheDate, 'MMdd') >= @FiscalYearStartMMDD 
                  THEN YEAR(TheDate) + 1 ELSE YEAR(TheDate) END)
            - (CASE WHEN FORMAT(@TodayDate, 'MMdd') >= @FiscalYearStartMMDD 
                  THEN YEAR(@TodayDate) + 1 ELSE YEAR(@TodayDate) END),
        RelativeFiscalHalf = (CASE 
                                 WHEN ((MONTH(TheDate) - CAST(LEFT(@FiscalYearStartMMDD,2) AS INT) + 12) % 12) < 6 
                                      THEN 1 ELSE 2 END)
            - (CASE WHEN ((MONTH(@TodayDate) - CAST(LEFT(@FiscalYearStartMMDD,2) AS INT) + 12) % 12) < 6 
                    THEN 1 ELSE 2 END)
            + ((CASE WHEN FORMAT(TheDate, 'MMdd') >= @FiscalYearStartMMDD 
                     THEN YEAR(TheDate) + 1 ELSE YEAR(TheDate) END)
               - (CASE WHEN FORMAT(@TodayDate, 'MMdd') >= @FiscalYearStartMMDD 
                     THEN YEAR(@TodayDate) + 1 ELSE YEAR(@TodayDate) END)) * 2,
        RelativeFiscalQuarter = ((MONTH(TheDate) - CAST(LEFT(@FiscalYearStartMMDD,2) AS INT) + 12) % 12) / 3 + 1
            - (((MONTH(@TodayDate) - CAST(LEFT(@FiscalYearStartMMDD,2) AS INT) + 12) % 12) / 3 + 1)
            + ((CASE WHEN FORMAT(TheDate, 'MMdd') >= @FiscalYearStartMMDD 
                     THEN YEAR(TheDate) + 1 ELSE YEAR(TheDate) END)
               - (CASE WHEN FORMAT(@TodayDate, 'MMdd') >= @FiscalYearStartMMDD 
                     THEN YEAR(@TodayDate) + 1 ELSE YEAR(@TodayDate) END)) * 4,
        RelativeWeekStartMonday = DATEDIFF(
            WEEK,
            DATEADD(DAY, -((DATEPART(WEEKDAY, @TodayDate) + @@DATEFIRST - 2) % 7), @TodayDate),
            DATEADD(DAY, -((DATEPART(WEEKDAY, TheDate) + @@DATEFIRST - 2) % 7), TheDate)
        ),
        RelativeWeekStartSunday = DATEDIFF(
            WEEK,
            DATEADD(DAY, -DATEPART(WEEKDAY, @TodayDate) + 1, @TodayDate),
            DATEADD(DAY, -DATEPART(WEEKDAY, TheDate) + 1, TheDate)
        ),

        -- Flags
        IsWeekday        = CASE WHEN DATENAME(WEEKDAY, TheDate) NOT IN ('Saturday','Sunday') THEN 1 ELSE 0 END,
        IsWeekend        = CASE WHEN DATENAME(WEEKDAY, TheDate) IN ('Saturday','Sunday') THEN 1 ELSE 0 END,
        IsMTDToday       = CASE WHEN DAY(TheDate) <= DAY(@TodayDate) THEN 1 ELSE 0 END,
        IsMTDYesterday   = CASE WHEN DAY(TheDate) <= DAY(@YesterdayDate) THEN 1 ELSE 0 END,
        IsYTDToday       = CASE WHEN TheDate <= @TodayDate AND YEAR(TheDate) = YEAR(@TodayDate) THEN 1 ELSE 0 END,
        IsYTDYesterday   = CASE WHEN TheDate <= @YesterdayDate AND YEAR(TheDate) = YEAR(@YesterdayDate) THEN 1 ELSE 0 END,

        -- Correct fiscal YTD flags: only dates between current fiscal year start and today/yesterday
        IsFiscalYTDToday = CASE 
                               WHEN TheDate >= @CurrentFiscalYearStart 
                                    AND TheDate <= @TodayDate 
                               THEN 1 ELSE 0 END,
        IsFiscalYTDYesterday = CASE 
                                   WHEN TheDate >= @CurrentFiscalYearStart 
                                        AND TheDate <= @YesterdayDate 
                                   THEN 1 ELSE 0 END
    FROM DateSequence
    OPTION (MAXRECURSION 0);


    -- Dynamic Holiday Flag Update
    DECLARE @HolidaySQL NVARCHAR(MAX) = '';
    DECLARE @HolidayType VARCHAR(100);
    DECLARE @ColumnName SYSNAME;

    DECLARE holiday_cursor CURSOR FOR
    
    SELECT 
        c.COLUMN_NAME,
        REPLACE(c.COLUMN_NAME, 'Holiday_', '') AS HolidayType
    FROM 
        INFORMATION_SCHEMA.COLUMNS c
    WHERE 
        c.TABLE_NAME = 'DimDate'
        AND c.TABLE_SCHEMA = 'dbo'
        AND c.COLUMN_NAME LIKE 'Holiday%'


    OPEN holiday_cursor;
    FETCH NEXT FROM holiday_cursor INTO @ColumnName, @HolidayType;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @HolidaySQL = '
        UPDATE d
        SET d.' + QUOTENAME(@ColumnName) + ' = CASE WHEN ph.DimDate_SK IS NOT NULL THEN 1 ELSE 0 END
        FROM dbo.DimDate d
        LEFT JOIN dbo.PublicHoliday ph 
            ON ph.DimDate_SK = d.DimDate_SK 
            AND ph.PublicHolidayType = ''' + @HolidayType + ''';';
    
        EXEC sp_executesql @HolidaySQL;
    
        FETCH NEXT FROM holiday_cursor INTO @ColumnName, @HolidayType;
    END;

    CLOSE holiday_cursor;
    DEALLOCATE holiday_cursor;

DECLARE @HolidayRelativeBusinessDaysSQL NVARCHAR(MAX) = '';

-- Build dynamic SQL for each holiday column
SELECT @HolidayRelativeBusinessDaysSQL = @HolidayRelativeBusinessDaysSQL +
'
UPDATE d
SET ' + COLUMN_NAME + ' =
    CASE 
        WHEN d.[Date] < @TodayDate THEN
            (
                (SELECT COUNT(*)
                 FROM dbo.DimDate wd
                 WHERE wd.[Date] > d.[Date]
                   AND wd.[Date] <= @TodayDate
                   AND wd.IsWeekend = 0)
              -
                (SELECT COUNT(*)
                 FROM dbo.DimDate h
                 WHERE h.[Date] > d.[Date]
                   AND h.[Date] <= @TodayDate
                   AND h.' + QUOTENAME(COLUMN_NAME) + ' = 1
                   AND h.IsWeekend = 0)
            ) * -1
        WHEN d.[Date] > @TodayDate THEN
            (
                (SELECT COUNT(*)
                 FROM dbo.DimDate wd
                 WHERE wd.[Date] > @TodayDate
                   AND wd.[Date] <= d.[Date]
                   AND wd.IsWeekend = 0)
              -
                (SELECT COUNT(*)
                 FROM dbo.DimDate h
                 WHERE h.[Date] > @TodayDate
                   AND h.[Date] <= d.[Date]
                   AND h.' + QUOTENAME(COLUMN_NAME) + ' = 1
                   AND h.IsWeekend = 0)
            )
        ELSE 0
    END
FROM dbo.DimDate d;
'
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'DimDate'
  AND COLUMN_NAME LIKE 'RelativeBusinessDays_%';

-- Execute the dynamic SQL
EXEC sp_executesql @HolidayRelativeBusinessDaysSQL, N'@TodayDate DATE', @TodayDate = @TodayDate;




END
GO

