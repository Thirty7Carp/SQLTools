CREATE TABLE Common.DimTime
(
    DimTime_SK              BIGINT       NOT NULL PRIMARY KEY, -- Surrogate Key
    Time                    TIME(0)      NOT NULL,             -- Full time value (HH:MM:SS)

    -- Numeric components
    Second                  TINYINT      NOT NULL,             -- Second (0-59)
    Minute                  TINYINT      NOT NULL,             -- Minute (0-59)
    Hour24                  TINYINT      NOT NULL,             -- Hour in 24-hour format (0-23)
    Hour12                  TINYINT      NOT NULL,             -- Hour in 12-hour format (1-12)

    AMPM                    CHAR(2)      NOT NULL,             -- AM or PM

    -- Interval24 groupings (time values aligned to start of bucket)
    Interval24_Second       TIME(0)      NOT NULL,             -- Exact second (HH:MM:SS)
    Interval24_Minute       TIME(0)      NOT NULL,             -- Start of the minute (HH:MM:00)
    Interval24_5Min         TIME(0)      NOT NULL,             -- Start of 5-min interval
    Interval24_QuarterHour  TIME(0)      NOT NULL,             -- Start of quarter-hour interval
    Interval24_HalfHour     TIME(0)      NOT NULL,             -- Start of half-hour interval
    Interval24_Hour         TIME(0)      NOT NULL,             -- Start of hour interval

    -- Interval12 groupings (time values aligned to start of bucket)
    Interval12_Second       TIME(0)      NOT NULL,             -- Exact second (HH:MM:SS, 12-hour clock)
    Interval12_Minute       TIME(0)      NOT NULL,             -- Start of the minute (HH:MM:00, 12-hour clock)
    Interval12_5Min         TIME(0)      NOT NULL,             -- Start of 5-min interval (12-hour clock)
    Interval12_QuarterHour  TIME(0)      NOT NULL,             -- Start of quarter-hour interval (12-hour clock)
    Interval12_HalfHour     TIME(0)      NOT NULL,             -- Start of half-hour interval (12-hour clock)
    Interval12_Hour         TIME(0)      NOT NULL              -- Start of hour interval (12-hour clock)
);
