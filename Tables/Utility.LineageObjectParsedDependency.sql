CREATE TABLE Utility.LineageObjectParsedDependency (
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
);