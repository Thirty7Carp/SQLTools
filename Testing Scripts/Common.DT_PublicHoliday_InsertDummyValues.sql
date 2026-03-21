-- WA Public Holidays INSERT Script
-- For Perth, Western Australia
-- Years: 2020-2050
-- Note: Easter dates calculated, other holidays follow standard rules
-- Substitute holidays occur when the actual holiday falls on a weekend

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Clear existing WA State holidays (optional - comment out if you want to keep existing data)
-- DELETE FROM Common.PublicHoliday WHERE PublicHolidayType = 'AustraliaWA';

Truncate table Common.DT_PublicHoliday

-- 2020 Holidays
INSERT INTO Common.DT_PublicHoliday (DimDate_SK, PublicHolidayType, PublicHolidayName, PublicHolidaySubstitute) VALUES
(20200101, 'AustraliaWA', 'New Year''s Day', 0),
(20200127, 'AustraliaWA', 'Australia Day', 0),
(20200302, 'AustraliaWA', 'Labour Day', 0),
(20200410, 'AustraliaWA', 'Good Friday', 0),
(20200413, 'AustraliaWA', 'Easter Monday', 0),
(20200425, 'AustraliaWA', 'Anzac Day', 0),
(20200427, 'AustraliaWA', 'Anzac Day', 1), -- substitute (Anzac fell on Saturday)
(20200601, 'AustraliaWA', 'Western Australia Day', 0),
(20200928, 'AustraliaWA', 'Queen''s Birthday', 0),
(20201225, 'AustraliaWA', 'Christmas Day', 0),
(20201226, 'AustraliaWA', 'Boxing Day', 0),
(20201228, 'AustraliaWA', 'Boxing Day', 1); -- substitute (Boxing Day fell on Saturday)

-- 2021 Holidays
INSERT INTO Common.DT_PublicHoliday (DimDate_SK, PublicHolidayType, PublicHolidayName, PublicHolidaySubstitute) VALUES
(20210101, 'AustraliaWA', 'New Year''s Day', 0),
(20210126, 'AustraliaWA', 'Australia Day', 0),
(20210301, 'AustraliaWA', 'Labour Day', 0),
(20210402, 'AustraliaWA', 'Good Friday', 0),
(20210405, 'AustraliaWA', 'Easter Monday', 0),
(20210425, 'AustraliaWA', 'Anzac Day', 0),
(20210426, 'AustraliaWA', 'Anzac Day', 1), -- substitute (Anzac fell on Sunday)
(20210607, 'AustraliaWA', 'Western Australia Day', 0),
(20210927, 'AustraliaWA', 'Queen''s Birthday', 0),
(20211225, 'AustraliaWA', 'Christmas Day', 0),
(20211226, 'AustraliaWA', 'Boxing Day', 0),
(20211227, 'AustraliaWA', 'Christmas Day', 1), -- substitute (Christmas fell on Saturday)
(20211228, 'AustraliaWA', 'Boxing Day', 1); -- substitute (Boxing Day fell on Sunday)

-- 2022 Holidays (Easter Sunday became a public holiday from 2022, Queen's Birthday renamed to King's Birthday)
INSERT INTO Common.DT_PublicHoliday (DimDate_SK, PublicHolidayType, PublicHolidayName, PublicHolidaySubstitute) VALUES
(20220101, 'AustraliaWA', 'New Year''s Day', 0),
(20220103, 'AustraliaWA', 'New Year''s Day', 1), -- substitute (New Year fell on Saturday)
(20220126, 'AustraliaWA', 'Australia Day', 0),
(20220307, 'AustraliaWA', 'Labour Day', 0),
(20220415, 'AustraliaWA', 'Good Friday', 0),
(20220417, 'AustraliaWA', 'Easter Sunday', 0), -- NEW from 2022
(20220418, 'AustraliaWA', 'Easter Monday', 0),
(20220425, 'AustraliaWA', 'Anzac Day', 0),
(20220606, 'AustraliaWA', 'Western Australia Day', 0),
(20220922, 'AustraliaWA', 'National Day of Mourning', 0), -- Special one-time holiday
(20220926, 'AustraliaWA', 'King''s Birthday', 0), -- Renamed from Queen's Birthday
(20221225, 'AustraliaWA', 'Christmas Day', 0),
(20221226, 'AustraliaWA', 'Christmas Day', 1), -- substitute (Christmas fell on Sunday)
(20221226, 'AustraliaWA', 'Boxing Day', 0),
(20221227, 'AustraliaWA', 'Boxing Day', 1); -- substitute (Boxing Day fell on Monday)

-- 2023 Holidays
INSERT INTO Common.DT_PublicHoliday (DimDate_SK, PublicHolidayType, PublicHolidayName, PublicHolidaySubstitute) VALUES
(20230101, 'AustraliaWA', 'New Year''s Day', 0),
(20230102, 'AustraliaWA', 'New Year''s Day', 1), -- substitute (New Year fell on Sunday)
(20230126, 'AustraliaWA', 'Australia Day', 0),
(20230306, 'AustraliaWA', 'Labour Day', 0),
(20230407, 'AustraliaWA', 'Good Friday', 0),
(20230409, 'AustraliaWA', 'Easter Sunday', 0),
(20230410, 'AustraliaWA', 'Easter Monday', 0),
(20230425, 'AustraliaWA', 'Anzac Day', 0),
(20230605, 'AustraliaWA', 'Western Australia Day', 0),
(20230925, 'AustraliaWA', 'King''s Birthday', 0),
(20231225, 'AustraliaWA', 'Christmas Day', 0),
(20231226, 'AustraliaWA', 'Boxing Day', 0);

-- 2024 Holidays
INSERT INTO Common.DT_PublicHoliday (DimDate_SK, PublicHolidayType, PublicHolidayName, PublicHolidaySubstitute) VALUES
(20240101, 'AustraliaWA', 'New Year''s Day', 0),
(20240126, 'AustraliaWA', 'Australia Day', 0),
(20240304, 'AustraliaWA', 'Labour Day', 0),
(20240329, 'AustraliaWA', 'Good Friday', 0),
(20240331, 'AustraliaWA', 'Easter Sunday', 0),
(20240401, 'AustraliaWA', 'Easter Monday', 0),
(20240425, 'AustraliaWA', 'Anzac Day', 0),
(20240603, 'AustraliaWA', 'Western Australia Day', 0),
(20240923, 'AustraliaWA', 'King''s Birthday', 0),
(20241225, 'AustraliaWA', 'Christmas Day', 0),
(20241226, 'AustraliaWA', 'Boxing Day', 0);

-- 2025 Holidays
INSERT INTO Common.DT_PublicHoliday (DimDate_SK, PublicHolidayType, PublicHolidayName, PublicHolidaySubstitute) VALUES
(20250101, 'AustraliaWA', 'New Year''s Day', 0),
(20250127, 'AustraliaWA', 'Australia Day', 1), -- substitute (Australia Day fell on Sunday)
(20250303, 'AustraliaWA', 'Labour Day', 0),
(20250418, 'AustraliaWA', 'Good Friday', 0),
(20250420, 'AustraliaWA', 'Easter Sunday', 0),
(20250421, 'AustraliaWA', 'Easter Monday', 0),
(20250425, 'AustraliaWA', 'Anzac Day', 0),
(20250602, 'AustraliaWA', 'Western Australia Day', 0),
(20250929, 'AustraliaWA', 'King''s Birthday', 0),
(20251225, 'AustraliaWA', 'Christmas Day', 0),
(20251226, 'AustraliaWA', 'Boxing Day', 0);

-- 2026 Holidays
INSERT INTO Common.DT_PublicHoliday (DimDate_SK, PublicHolidayType, PublicHolidayName, PublicHolidaySubstitute) VALUES
(20260101, 'AustraliaWA', 'New Year''s Day', 0),
(20260126, 'AustraliaWA', 'Australia Day', 0),
(20260302, 'AustraliaWA', 'Labour Day', 0),
(20260403, 'AustraliaWA', 'Good Friday', 0),
(20260405, 'AustraliaWA', 'Easter Sunday', 0),
(20260406, 'AustraliaWA', 'Easter Monday', 0),
(20260425, 'AustraliaWA', 'Anzac Day', 0),
(20260427, 'AustraliaWA', 'Anzac Day', 1), -- substitute (Anzac fell on Saturday)
(20260601, 'AustraliaWA', 'Western Australia Day', 0),
(20260928, 'AustraliaWA', 'King''s Birthday', 0),
(20261225, 'AustraliaWA', 'Christmas Day', 0),
(20261226, 'AustraliaWA', 'Boxing Day', 0),
(20261228, 'AustraliaWA', 'Boxing Day', 1); -- substitute (Boxing Day fell on Saturday)

-- 2027 Holidays
INSERT INTO Common.DT_PublicHoliday (DimDate_SK, PublicHolidayType, PublicHolidayName, PublicHolidaySubstitute) VALUES
(20270101, 'AustraliaWA', 'New Year''s Day', 0),
(20270126, 'AustraliaWA', 'Australia Day', 0),
(20270301, 'AustraliaWA', 'Labour Day', 0),
(20270326, 'AustraliaWA', 'Good Friday', 0),
(20270328, 'AustraliaWA', 'Easter Sunday', 0),
(20270329, 'AustraliaWA', 'Easter Monday', 0),
(20270425, 'AustraliaWA', 'Anzac Day', 0),
(20270426, 'AustraliaWA', 'Anzac Day', 1), -- substitute (Anzac fell on Sunday)
(20270607, 'AustraliaWA', 'Western Australia Day', 0),
(20270927, 'AustraliaWA', 'King''s Birthday', 0),
(20271225, 'AustraliaWA', 'Christmas Day', 0),
(20271226, 'AustraliaWA', 'Boxing Day', 0),
(20271227, 'AustraliaWA', 'Christmas Day', 1), -- substitute (Christmas fell on Saturday)
(20271228, 'AustraliaWA', 'Boxing Day', 1); -- substitute (Boxing Day fell on Sunday)

-- 2028 Holidays
INSERT INTO Common.DT_PublicHoliday (DimDate_SK, PublicHolidayType, PublicHolidayName, PublicHolidaySubstitute) VALUES
(20280101, 'AustraliaWA', 'New Year''s Day', 0),
(20280103, 'AustraliaWA', 'New Year''s Day', 1), -- substitute (New Year fell on Saturday)
(20280126, 'AustraliaWA', 'Australia Day', 0),
(20280306, 'AustraliaWA', 'Labour Day', 0),
(20280414, 'AustraliaWA', 'Good Friday', 0),
(20280416, 'AustraliaWA', 'Easter Sunday', 0),
(20280417, 'AustraliaWA', 'Easter Monday', 0),
(20280425, 'AustraliaWA', 'Anzac Day', 0),
(20280605, 'AustraliaWA', 'Western Australia Day', 0),
(20280925, 'AustraliaWA', 'King''s Birthday', 0),
(20281225, 'AustraliaWA', 'Christmas Day', 0),
(20281226, 'AustraliaWA', 'Boxing Day', 0);

-- 2029 Holidays
INSERT INTO Common.DT_PublicHoliday (DimDate_SK, PublicHolidayType, PublicHolidayName, PublicHolidaySubstitute) VALUES
(20290101, 'AustraliaWA', 'New Year''s Day', 0),
(20290126, 'AustraliaWA', 'Australia Day', 0),
(20290305, 'AustraliaWA', 'Labour Day', 0),
(20290330, 'AustraliaWA', 'Good Friday', 0),
(20290401, 'AustraliaWA', 'Easter Sunday', 0),
(20290402, 'AustraliaWA', 'Easter Monday', 0),
(20290425, 'AustraliaWA', 'Anzac Day', 0),
(20290604, 'AustraliaWA', 'Western Australia Day', 0),
(20290924, 'AustraliaWA', 'King''s Birthday', 0),
(20291225, 'AustraliaWA', 'Christmas Day', 0),
(20291226, 'AustraliaWA', 'Boxing Day', 0);

-- 2030 Holidays
INSERT INTO Common.DT_PublicHoliday (DimDate_SK, PublicHolidayType, PublicHolidayName, PublicHolidaySubstitute) VALUES
(20300101, 'AustraliaWA', 'New Year''s Day', 0),
(20300128, 'AustraliaWA', 'Australia Day', 1), -- substitute (Australia Day fell on Saturday)
(20300304, 'AustraliaWA', 'Labour Day', 0),
(20300419, 'AustraliaWA', 'Good Friday', 0),
(20300421, 'AustraliaWA', 'Easter Sunday', 0),
(20300422, 'AustraliaWA', 'Easter Monday', 0),
(20300425, 'AustraliaWA', 'Anzac Day', 0),
(20300603, 'AustraliaWA', 'Western Australia Day', 0),
(20300930, 'AustraliaWA', 'King''s Birthday', 0),
(20301225, 'AustraliaWA', 'Christmas Day', 0),
(20301226, 'AustraliaWA', 'Boxing Day', 0);

-- 2031 Holidays
INSERT INTO Common.DT_PublicHoliday (DimDate_SK, PublicHolidayType, PublicHolidayName, PublicHolidaySubstitute) VALUES
(20310101, 'AustraliaWA', 'New Year''s Day', 0),
(20310127, 'AustraliaWA', 'Australia Day', 1), -- substitute (Australia Day fell on Sunday)
(20310303, 'AustraliaWA', 'Labour Day', 0),
(20310411, 'AustraliaWA', 'Good Friday', 0),
(20310413, 'AustraliaWA', 'Easter Sunday', 0),
(20310414, 'AustraliaWA', 'Easter Monday', 0),
(20310425, 'AustraliaWA', 'Anzac Day', 0),
(20310602, 'AustraliaWA', 'Western Australia Day', 0),
(20310929, 'AustraliaWA', 'King''s Birthday', 0),
(20311225, 'AustraliaWA', 'Christmas Day', 0),
(20311226, 'AustraliaWA', 'Boxing Day', 0);

-- 2032 Holidays
INSERT INTO Common.DT_PublicHoliday (DimDate_SK, PublicHolidayType, PublicHolidayName, PublicHolidaySubstitute) VALUES
(20320101, 'AustraliaWA', 'New Year''s Day', 0),
(20320126, 'AustraliaWA', 'Australia Day', 0),
(20320301, 'AustraliaWA', 'Labour Day', 0),
(20320326, 'AustraliaWA', 'Good Friday', 0),
(20320328, 'AustraliaWA', 'Easter Sunday', 0),
(20320329, 'AustraliaWA', 'Easter Monday', 0),
(20320425, 'AustraliaWA', 'Anzac Day', 0),
(20320426, 'AustraliaWA', 'Anzac Day', 1), -- substitute (Anzac fell on Sunday)
(20320607, 'AustraliaWA', 'Western Australia Day', 0),
(20320927, 'AustraliaWA', 'King''s Birthday', 0),
(20321225, 'AustraliaWA', 'Christmas Day', 0),
(20321226, 'AustraliaWA', 'Boxing Day', 0),
(20321227, 'AustraliaWA', 'Christmas Day', 1), -- substitute (Christmas fell on Saturday)
(20321228, 'AustraliaWA', 'Boxing Day', 1); -- substitute (Boxing Day fell on Sunday)

-- 2033 Holidays
INSERT INTO Common.DT_PublicHoliday (DimDate_SK, PublicHolidayType, PublicHolidayName, PublicHolidaySubstitute) VALUES
(20330101, 'AustraliaWA', 'New Year''s Day', 0),
(20330103, 'AustraliaWA', 'New Year''s Day', 1), -- substitute (New Year fell on Saturday)
(20330126, 'AustraliaWA', 'Australia Day', 0),
(20330307, 'AustraliaWA', 'Labour Day', 0),
(20330415, 'AustraliaWA', 'Good Friday', 0),
(20330417, 'AustraliaWA', 'Easter Sunday', 0),
(20330418, 'AustraliaWA', 'Easter Monday', 0),
(20330425, 'AustraliaWA', 'Anzac Day', 0),
(20330606, 'AustraliaWA', 'Western Australia Day', 0),
(20330926, 'AustraliaWA', 'King''s Birthday', 0),
(20331225, 'AustraliaWA', 'Christmas Day', 0),
(20331226, 'AustraliaWA', 'Boxing Day', 0),
(20331227, 'AustraliaWA', 'Christmas Day', 1), -- substitute (Christmas fell on Sunday)
(20331227, 'AustraliaWA', 'Boxing Day', 1) -- substitute (Boxing Day fell on Monday)

/* Test Holidays for new Holiday Types */
, (20331227, 'CountryStateAA', 'Boxing Day', 1) -- substitute (Boxing Day fell on Monday)
, (20331227, 'CountryStateBB', 'Boxing Day', 1) -- substitute (Boxing Day fell on Monday)
, (20331227, 'CountryStateCC', 'Boxing Day', 1) -- substitute (Boxing Day fell on Monday)
, (20331227, 'CountryStateDD', 'Boxing Day', 1) -- substitute (Boxing Day fell on Monday)
, (20331227, 'CountryStateEE', 'Boxing Day', 1) -- substitute (Boxing Day fell on Monday)
, (20280605, 'CountryStateFF', 'Western Australia Day', 1)
, (20291226, 'CountryStateFF', 'Boxing Day', 0)
, (20331227, 'CountryStateFF', 'Boxing Day', 1) -- substitute (Boxing Day fell on Monday)
, (20220126, 'CountryStateFF', 'Australia Day', 0)

/* Update to the CountBusinessDays holidays value */
Update ph
set ph.CountBusinessDays = 1
from Common.DT_PublicHoliday ph
where ph.PublicHolidayType = 'AustraliaWA'



Update ph
set ph.CountBusinessDays = 1
from Common.DT_PublicHoliday ph
where ph.PublicHolidayType = 'CountryStateFF'
