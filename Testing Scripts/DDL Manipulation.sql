-- Drop temp table if it already exists
IF OBJECT_ID('tempdb..#Definitions') IS NOT NULL DROP TABLE #Definitions
IF OBJECT_ID('tempdb..#DDLResults') IS NOT NULL DROP TABLE #DDLResults

-- Pre-process the definitions to normalise whitespace
SELECT
    ObjectID,
    ServerName,
    DatabaseName,
    SchemaName,
    ObjectName,
    ObjectType,
    REPLACE(
    REPLACE(
    REPLACE(
    REPLACE(
        UPPER(ObjectDefinition)
    , 'IF EXISTS', '')
    , CHAR(13), ' ')
    , CHAR(10), ' ')
    , CHAR(9),  ' ')
    AS ObjectDefinition
INTO #Definitions
FROM Utility.LineageObjectDefinitions

-- Keep collapsing double spaces until none remain
WHILE EXISTS (SELECT 1 FROM #Definitions WHERE ObjectDefinition LIKE '%  %')
BEGIN
    UPDATE #Definitions
    SET ObjectDefinition = REPLACE(ObjectDefinition, '  ', ' ')
    WHERE ObjectDefinition LIKE '%  %'
END

-- Calculate max definition length after cleaning
DECLARE @MaxLen INT
SELECT @MaxLen = MAX(LEN(ObjectDefinition)) FROM #Definitions

-- Now run the main query against the cleaned temp table
;WITH Keywords AS (
    SELECT 'ALTER TABLE'      AS Keyword, 'ALTER'    AS DDLType, 'TABLE'     AS DDLObjectType, 12 AS KeywordLen UNION ALL
    SELECT 'ALTER VIEW'       AS Keyword, 'ALTER'    AS DDLType, 'VIEW'      AS DDLObjectType, 11 AS KeywordLen UNION ALL
    SELECT 'DROP TABLE'       AS Keyword, 'DROP'     AS DDLType, 'TABLE'     AS DDLObjectType, 11 AS KeywordLen UNION ALL
    SELECT 'DROP VIEW'        AS Keyword, 'DROP'     AS DDLType, 'VIEW'      AS DDLObjectType, 10 AS KeywordLen UNION ALL
    SELECT 'DROP PROCEDURE'   AS Keyword, 'DROP'     AS DDLType, 'PROCEDURE' AS DDLObjectType, 15 AS KeywordLen UNION ALL
    SELECT 'TRUNCATE TABLE'   AS Keyword, 'TRUNCATE' AS DDLType, 'TABLE'     AS DDLObjectType, 15 AS KeywordLen UNION ALL
    SELECT 'CREATE TABLE'     AS Keyword, 'CREATE'   AS DDLType, 'TABLE'     AS DDLObjectType, 13 AS KeywordLen UNION ALL
    SELECT 'CREATE VIEW'      AS Keyword, 'CREATE'   AS DDLType, 'VIEW'      AS DDLObjectType, 12 AS KeywordLen UNION ALL
    SELECT 'CREATE PROCEDURE' AS Keyword, 'CREATE'   AS DDLType, 'PROCEDURE' AS DDLObjectType, 17 AS KeywordLen UNION ALL
    SELECT 'CREATE INDEX'     AS Keyword, 'CREATE'   AS DDLType, 'INDEX'     AS DDLObjectType, 13 AS KeywordLen
),
Numbers AS (
    SELECT 1 AS N
    UNION ALL
    SELECT N + 1
    FROM Numbers
    WHERE N < @MaxLen
),
Matches AS (
    SELECT
        d.ObjectID,
        d.ServerName,
        d.DatabaseName,
        d.SchemaName,
        d.ObjectName,
        k.DDLType,
        k.DDLObjectType,
        k.KeywordLen,
        n.N AS MatchPosition,
        LTRIM(RTRIM(SUBSTRING(d.ObjectDefinition, n.N + k.KeywordLen, 350))) AS RawTarget
    FROM #Definitions d
    CROSS JOIN Keywords k
    JOIN Numbers n ON SUBSTRING(d.ObjectDefinition, n.N, k.KeywordLen) = k.Keyword
    WHERE n.N <= LEN(d.ObjectDefinition)
)
SELECT
    ObjectID,
    ServerName,
    DatabaseName,
    SchemaName,
    ObjectName,
    DDLType,
    DDLObjectType,
    RawTarget AS DDLTarget
INTO #DDLResults
FROM Matches
ORDER BY DatabaseName, SchemaName, ObjectName, MatchPosition
OPTION (MAXRECURSION 0)

-- Remove anything after the first space that is not within brackets
-- Use '] ' to find the end of the object name, skipping schema.object separators
UPDATE #DDLResults
SET DDLTarget = CASE
    WHEN DDLTarget LIKE '%[[]%'
    THEN LEFT(DDLTarget, CHARINDEX('] ', DDLTarget + ' '))
    ELSE LEFT(DDLTarget, CASE
        WHEN CHARINDEX(' ', DDLTarget) = 0 THEN LEN(DDLTarget)
        ELSE CHARINDEX(' ', DDLTarget) - 1
    END)
END

-- Remove temp table references
DELETE FROM #DDLResults
WHERE DDLTarget LIKE '%#%'

-- Remove dynamic SQL references (containing a single quote)
DELETE FROM #DDLResults
WHERE DDLTarget LIKE '%''%'

-- Strip semicolons from DDLTarget
UPDATE #DDLResults
SET DDLTarget = REPLACE(DDLTarget, ';', '')


