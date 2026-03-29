IF OBJECT_ID(N'Utility.LNG_ObjectParsedDependency', N'U') IS NULL

BEGIN

CREATE TABLE Utility.LNG_ObjectParsedDependency (
    ParsedDependencyID BIGINT IDENTITY(1,1) PRIMARY KEY,
    SourceServer NVARCHAR(128) NOT NULL,
    SourceDatabase NVARCHAR(128) NOT NULL,
    SourceSchema NVARCHAR(128) NOT NULL,
    SourceObject NVARCHAR(128) NOT NULL,
    OperationType NVARCHAR(50) NOT NULL,
    TargetServer NVARCHAR(128) NOT NULL,
    TargetDatabase NVARCHAR(128) NOT NULL,
    TargetSchema NVARCHAR(128) NOT NULL,
    TargetObject NVARCHAR(128) NOT NULL,
    CaptureDate DATETIME DEFAULT GETDATE()
)

END