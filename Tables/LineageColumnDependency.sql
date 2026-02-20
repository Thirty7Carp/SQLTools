drop table if exists Utility.LineageColumnDependency

CREATE TABLE Utility.LineageColumnDependency (
    ColumnLineageID BIGINT IDENTITY(1,1) PRIMARY KEY,
    SourceServer NVARCHAR(128) NOT NULL DEFAULT @@SERVERNAME,
    SourceDatabase NVARCHAR(128) NOT NULL,
    SourceSchema NVARCHAR(128) NOT NULL,
    SourceObject NVARCHAR(128) NOT NULL,
    SourceColumn NVARCHAR(128) NOT NULL,
    TargetServer NVARCHAR(128) NOT NULL DEFAULT @@SERVERNAME,
    TargetDatabase NVARCHAR(128) NOT NULL,
    TargetSchema NVARCHAR(128) NOT NULL,
    TargetObject NVARCHAR(128) NOT NULL,
    TargetColumn NVARCHAR(128) NOT NULL,
    TransformationType NVARCHAR(100), -- e.g., 'Direct', 'Calculated', 'Aggregated'
    CaptureDate DATETIME DEFAULT GETDATE()
)

CREATE INDEX IX_ColumnLineage_Source ON Utility.LineageColumnDependency(SourceServer, SourceDatabase, SourceSchema, SourceObject, SourceColumn);
CREATE INDEX IX_ColumnLineage_Target ON Utility.LineageColumnDependency(TargetServer, TargetDatabase, TargetSchema, TargetObject, TargetColumn);