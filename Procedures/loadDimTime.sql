CREATE PROCEDURE Common.loadDimTime
AS
BEGIN
    SET NOCOUNT ON;

    -- Clear existing data
    TRUNCATE TABLE Common.DimTime;

    -- Insert placeholder row for NULL time values
    INSERT INTO Common.DimTime
    (
        DimTime_SK, Time, Second, Minute, Hour24, Hour12, AMPM,
        Interval24_Second, Interval24_Minute, Interval24_5Min, Interval24_QuarterHour, Interval24_HalfHour, Interval24_Hour,
        Interval12_Second, Interval12_Minute, Interval12_5Min, Interval12_QuarterHour, Interval12_HalfHour, Interval12_Hour
    )
    VALUES
    (
        -1, '00:00:00', 0, 0, 0, 0, 'NA',
        '00:00:00', '00:00:00', '00:00:00', '00:00:00', '00:00:00', '00:00:00',
        '00:00:00', '00:00:00', '00:00:00', '00:00:00', '00:00:00', '00:00:00'
    );

    DECLARE @SecondsInDay INT = 24 * 60 * 60; -- 86,400 seconds
    DECLARE @Counter INT = 0;

    WHILE @Counter < @SecondsInDay
    BEGIN
        DECLARE @CurrentTime TIME(0) = DATEADD(SECOND, @Counter, '00:00:00');
        DECLARE @Hour24 INT = DATEPART(HOUR, @CurrentTime);
        DECLARE @Hour12 INT = CASE WHEN @Hour24 % 12 = 0 THEN 12 ELSE @Hour24 % 12 END;
        DECLARE @MinuteNum INT = DATEPART(MINUTE, @CurrentTime);
        DECLARE @SecondNum INT = DATEPART(SECOND, @CurrentTime);
        DECLARE @AMPM CHAR(2) = CASE WHEN @Hour24 < 12 THEN 'AM' ELSE 'PM' END;

        -- Interval24 buckets
        DECLARE @Interval24_Second TIME(0) = @CurrentTime;
        DECLARE @Interval24_Minute TIME(0) = CAST(CONCAT(FORMAT(@Hour24,'00'), ':', FORMAT(@MinuteNum,'00'), ':00') AS TIME(0));
        DECLARE @Interval24_5Min TIME(0) = CAST(CONCAT(FORMAT(@Hour24,'00'), ':', FORMAT((@MinuteNum/5)*5,'00'), ':00') AS TIME(0));
        DECLARE @Interval24_QuarterHour TIME(0) = CAST(CONCAT(FORMAT(@Hour24,'00'), ':', FORMAT((@MinuteNum/15)*15,'00'), ':00') AS TIME(0));
        DECLARE @Interval24_HalfHour TIME(0) = CAST(CONCAT(FORMAT(@Hour24,'00'), ':', FORMAT((@MinuteNum/30)*30,'00'), ':00') AS TIME(0));
        DECLARE @Interval24_Hour TIME(0) = CAST(CONCAT(FORMAT(@Hour24,'00'), ':00:00') AS TIME(0));

        -- Interval12 buckets
        DECLARE @Interval12_Second TIME(0) = @CurrentTime;
        DECLARE @Interval12_Minute TIME(0) = CAST(CONCAT(FORMAT(@Hour12,'00'), ':', FORMAT(@MinuteNum,'00'), ':00') AS TIME(0));
        DECLARE @Interval12_5Min TIME(0) = CAST(CONCAT(FORMAT(@Hour12,'00'), ':', FORMAT((@MinuteNum/5)*5,'00'), ':00') AS TIME(0));
        DECLARE @Interval12_QuarterHour TIME(0) = CAST(CONCAT(FORMAT(@Hour12,'00'), ':', FORMAT((@MinuteNum/15)*15,'00'), ':00') AS TIME(0));
        DECLARE @Interval12_HalfHour TIME(0) = CAST(CONCAT(FORMAT(@Hour12,'00'), ':', FORMAT((@MinuteNum/30)*30,'00'), ':00') AS TIME(0));
        DECLARE @Interval12_Hour TIME(0) = CAST(CONCAT(FORMAT(@Hour12,'00'), ':00:00') AS TIME(0));

        INSERT INTO Common.DimTime
        (
            DimTime_SK, Time, Second, Minute, Hour24, Hour12, AMPM,
            Interval24_Second, Interval24_Minute, Interval24_5Min, Interval24_QuarterHour, Interval24_HalfHour, Interval24_Hour,
            Interval12_Second, Interval12_Minute, Interval12_5Min, Interval12_QuarterHour, Interval12_HalfHour, Interval12_Hour
        )
        VALUES
        (
            @Counter + 1,
            @CurrentTime,
            @SecondNum,
            @MinuteNum,
            @Hour24,
            @Hour12,
            @AMPM,
            @Interval24_Second, @Interval24_Minute, @Interval24_5Min, @Interval24_QuarterHour, @Interval24_HalfHour, @Interval24_Hour,
            @Interval12_Second, @Interval12_Minute, @Interval12_5Min, @Interval12_QuarterHour, @Interval12_HalfHour, @Interval12_Hour
        );

        SET @Counter = @Counter + 1;
    END;

    Print 'Loaded DimTime'
END;
