/* 
Run this immediately after midnight each night to update all the relative values.

Make sure to:
    - update the @FiscalYearStartMMDD, July 1 (0701) was set because Australia.
    - update the @UTCOffsetMinutes to reflect your local timezone, 480 was set because Perth. 
        That sets @Today as the date it is where you are right now.
    - Update the @MinimumDate if you need dates before 1800 for some reason.
    - Update the @MaximumDate if you need dates after 2099 for some reason.
*/

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [Common].[loadDimDate]
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

    TRUNCATE TABLE Common.DimDate;


    INSERT INTO Common.DimDate (
    DimDate_SK,
    Date,
    CalendarYear,
    Month,
    Day,
    MonthName,
    MonthShortName,
    MonthAndCalendarYear,
    DayName,
    CalendarQuarter,
    CalendarHalf,
    MonthStart,
    CalendarQuarterStart,
    CalendarHalfStart,
    WeekStartMonday,
    WeekStartSunday,
    UnixStartOfDay,
    UnixEndOfDay,
    FiscalYear,
    FiscalHalf,
    FiscalQuarter,
    FiscalYearStart,
    FiscalHalfStart,
    RelativeCalendarYear,
    RelativeMonth,
    RelativeDay,
    RelativeCalendarQuarter,
    RelativeCalendarHalf,
    RelativeFiscalYear,
    RelativeFiscalHalf,
    RelativeFiscalQuarter,
    RelativeWeekStartMonday,
    RelativeWeekStartSunday,
    IsEndOfMonth,
    IsWeekday,
    IsWeekend,
    IsMTDToday,
    IsMTDYesterday,
    IsYTDToday,
    IsYTDYesterday,
    IsFiscalYTDToday,
    IsFiscalYTDYesterday
    -- Holiday_* and RelativeBusinessDays_* columns also set to 0
)

VALUES
(
    -1,                -- DimDate_SK
    '0001-01-01',      -- Date
    0,                 -- CalendarYear
    0,                 -- Month
    0,                 -- Day
    'NA',              -- MonthName
    'NA',              -- MonthShortName
    'NA',              -- MonthAndCalendarYear
    'NA',              -- DayName
    0,                 -- CalendarQuarter
    0,                 -- CalendarHalf
    NULL,              -- MonthStart
    NULL,              -- CalendarQuarterStart
    NULL,              -- CalendarHalfStart
    NULL,              -- WeekStartMonday
    NULL,              -- WeekStartSunday
    0,                 -- UnixStartOfDay
    0,                 -- UnixEndOfDay
    0,                 -- FiscalYear
    0,                 -- FiscalHalf
    0,                 -- FiscalQuarter
    NULL,              -- FiscalYearStart
    NULL,              -- FiscalHalfStart
    0,                 -- RelativeCalendarYear
    0,                 -- RelativeMonth
    0,                 -- RelativeDay
    0,                 -- RelativeCalendarQuarter
    0,                 -- RelativeCalendarHalf
    0,                 -- RelativeFiscalYear
    0,                 -- RelativeFiscalHalf
    0,                 -- RelativeFiscalQuarter
    0,                 -- RelativeWeekStartMonday
    0,                 -- RelativeWeekStartSunday
    0,                 -- IsEndOfMonth
    0,                 -- IsWeekday
    0,                 -- IsWeekend
    0,                 -- IsMTDToday
    0,                 -- IsMTDYesterday
    0,                 -- IsYTDToday
    0,                 -- IsYTDYesterday
    0,                 -- IsFiscalYTDToday
    0                  -- IsFiscalYTDYesterday
),
(
    99991231,          -- DimDate_SK
    '9999-12-31',      -- Date
    0,                 -- CalendarYear
    0,                 -- Month
    0,                 -- Day
    'NA',              -- MonthName
    'NA',              -- MonthShortName
    'NA',              -- MonthAndCalendarYear
    'NA',              -- DayName
    0,                 -- CalendarQuarter
    0,                 -- CalendarHalf
    NULL,              -- MonthStart
    NULL,              -- CalendarQuarterStart
    NULL,              -- CalendarHalfStart
    NULL,              -- WeekStartMonday
    NULL,              -- WeekStartSunday
    0,                 -- UnixStartOfDay
    0,                 -- UnixEndOfDay
    0,                 -- FiscalYear
    0,                 -- FiscalHalf
    0,                 -- FiscalQuarter
    NULL,              -- FiscalYearStart
    NULL,              -- FiscalHalfStart
    0,                 -- RelativeCalendarYear
    0,                 -- RelativeMonth
    0,                 -- RelativeDay
    0,                 -- RelativeCalendarQuarter
    0,                 -- RelativeCalendarHalf
    0,                 -- RelativeFiscalYear
    0,                 -- RelativeFiscalHalf
    0,                 -- RelativeFiscalQuarter
    0,                 -- RelativeWeekStartMonday
    0,                 -- RelativeWeekStartSunday
    0,                 -- IsEndOfMonth
    0,                 -- IsWeekday
    0,                 -- IsWeekend
    0,                 -- IsMTDToday
    0,                 -- IsMTDYesterday
    0,                 -- IsYTDToday
    0,                 -- IsYTDYesterday
    0,                 -- IsFiscalYTDToday
    0                  -- IsFiscalYTDYesterday
    -- Holiday_* and RelativeBusinessDays_* columns also set to 0
);


    ;WITH DateSequence AS (
        SELECT CAST(@MinimumDate AS DATE) AS TheDate
        UNION ALL
        SELECT DATEADD(DAY, 1, TheDate)
        FROM DateSequence
        WHERE TheDate <= @MaximumDate
    )
    INSERT INTO Common.DimDate (
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
        IsEndOfMonth, IsWeekday, IsWeekend,
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
        isEndOfMonth    = case when eomonth(TheDate) = TheDate then 1 else 0 end,
        IsWeekday        = CASE WHEN DATENAME(WEEKDAY, TheDate) NOT IN ('Saturday','Sunday') THEN 1 ELSE 0 END,
        IsWeekend        = CASE WHEN DATENAME(WEEKDAY, TheDate) IN ('Saturday','Sunday') THEN 1 ELSE 0 END,
        IsMTDToday       = CASE WHEN DAY(TheDate) <= DAY(@TodayDate) THEN 1 ELSE 0 END,
        IsMTDYesterday   = CASE WHEN DAY(TheDate) <= DAY(@YesterdayDate) THEN 1 ELSE 0 END,
        IsYTDToday       = CASE WHEN FORMAT(TheDate, 'MMdd') <= FORMAT(@TodayDate, 'MMdd') THEN 1 ELSE 0 END,
        IsYTDYesterday   = CASE WHEN FORMAT(TheDate, 'MMdd') <= FORMAT(@YesterdayDate, 'MMdd') THEN 1 ELSE 0 END,

        -- Correct fiscal YTD flags: only dates between current fiscal year start and today/yesterday
         IsFiscalYTDToday = 
            CASE 
            WHEN @FiscalYearStartMMDD = FORMAT(@TodayDate, 'MMdd') THEN 1
            WHEN FORMAT(@TodayDate, 'MMdd') > @FiscalYearStartMMDD THEN
                CASE WHEN FORMAT(TheDate, 'MMdd') >= @FiscalYearStartMMDD AND FORMAT(TheDate, 'MMdd') <= FORMAT(@TodayDate, 'MMdd') THEN 1 ELSE 0 END
            ELSE
                CASE WHEN FORMAT(TheDate, 'MMdd') >= @FiscalYearStartMMDD OR FORMAT(TheDate, 'MMdd') <= FORMAT(@TodayDate, 'MMdd') THEN 1 ELSE 0 END
            END,

        IsFiscalYTDYesterday = CASE 
            WHEN @FiscalYearStartMMDD = FORMAT(@YesterdayDate, 'MMdd') THEN 0
            WHEN FORMAT(@YesterdayDate, 'MMdd') > @FiscalYearStartMMDD THEN
                CASE WHEN FORMAT(TheDate, 'MMdd') >= @FiscalYearStartMMDD AND FORMAT(TheDate, 'MMdd') <= FORMAT(@YesterdayDate, 'MMdd') THEN 1 ELSE 0 END
            ELSE
                CASE WHEN FORMAT(TheDate, 'MMdd') >= @FiscalYearStartMMDD OR FORMAT(TheDate, 'MMdd') <= FORMAT(@YesterdayDate, 'MMdd') THEN 1 ELSE 0 END
            END
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
        AND c.TABLE_SCHEMA = 'Common'
        AND c.COLUMN_NAME LIKE 'Holiday%'


    OPEN holiday_cursor;
    FETCH NEXT FROM holiday_cursor INTO @ColumnName, @HolidayType;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @HolidaySQL = '
        UPDATE d
        SET d.' + QUOTENAME(@ColumnName) + ' = CASE WHEN ph.DimDate_SK IS NOT NULL THEN 1 ELSE 0 END
        FROM Common.DimDate d
        LEFT JOIN Common.PublicHoliday ph 
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
SET RelativeBusinessDays_' + COLUMN_NAME + ' =
    CASE 
        WHEN d.[Date] < @TodayDate THEN
            (
                (SELECT COUNT(*)
                 FROM Common.DimDate wd
                 WHERE wd.[Date] > d.[Date]
                   AND wd.[Date] < @TodayDate
                   AND wd.IsWeekend = 0)
              -
                (SELECT COUNT(*)
                 FROM Common.DimDate h
                 WHERE h.[Date] > d.[Date]
                   AND h.[Date] < @TodayDate
                   AND h.' + QUOTENAME(COLUMN_NAME) + ' = 1
                   AND h.IsWeekend = 0)
            ) * -1
        WHEN d.[Date] > @TodayDate THEN
            (
                (SELECT COUNT(*)
                 FROM Common.DimDate wd
                 WHERE wd.[Date] > @TodayDate
                   AND wd.[Date] <= d.[Date]
                   AND wd.IsWeekend = 0)
              -
                (SELECT COUNT(*)
                 FROM Common.DimDate h
                 WHERE h.[Date] > @TodayDate
                   AND h.[Date] <= d.[Date]
                   AND h.' + QUOTENAME(COLUMN_NAME) + ' = 1
                   AND h.IsWeekend = 0)
            )
        ELSE 0
    END
FROM Common.DimDate d;
'
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_NAME = 'DimDate'
  AND c.COLUMN_NAME LIKE 'Holiday_%'
  AND EXISTS (
      SELECT 1
      FROM INFORMATION_SCHEMA.COLUMNS r
      WHERE r.TABLE_NAME = 'DimDate'
        AND r.COLUMN_NAME = 'RelativeBusinessDays_' + c.COLUMN_NAME
  );


-- Execute the dynamic SQL
EXEC sp_executesql @HolidayRelativeBusinessDaysSQL, N'@TodayDate DATE', @TodayDate = @TodayDate;




END
GO

