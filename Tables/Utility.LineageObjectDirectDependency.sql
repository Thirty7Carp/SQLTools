drop table if exists Utility.LineageObjectDirectDependency

-- Store direct dependencies between objects
CREATE TABLE Utility.LineageObjectDirectDependency (
    DependencyID BIGINT IDENTITY(1,1) PRIMARY KEY,
    SourceServer NVARCHAR(128) NOT NULL DEFAULT @@SERVERNAME,
    SourceDatabase NVARCHAR(128) NOT NULL,
    SourceSchema NVARCHAR(128) NOT NULL,
    SourceObject NVARCHAR(128) NOT NULL,
    SourceType NVARCHAR(60) NOT NULL,
    TargetServer NVARCHAR(128) NOT NULL DEFAULT @@SERVERNAME,
    TargetDatabase NVARCHAR(128) NOT NULL,
    TargetSchema NVARCHAR(128) NOT NULL,
    TargetObject NVARCHAR(128) NOT NULL,
    TargetType NVARCHAR(60) NOT NULL,
    CaptureDate DATETIME DEFAULT GETDATE()
);
GO


CREATE INDEX IX_ObjectDependencies_Source ON Utility.LineageObjectDirectDependency(SourceServer, SourceDatabase, SourceSchema, SourceObject);
CREATE INDEX IX_ObjectDependencies_Target ON Utility.LineageObjectDirectDependency(TargetServer, TargetDatabase, TargetSchema, TargetObject);
