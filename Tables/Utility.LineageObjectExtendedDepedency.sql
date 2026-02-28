Drop table if exists Utility.LineageObjectExtendedDependency

CREATE TABLE Utility.LineageObjectExtendedDependency (
    LineageID BIGINT IDENTITY(1,1) PRIMARY KEY,
    RootServer NVARCHAR(128) NOT NULL DEFAULT @@SERVERNAME,
    RootDatabase NVARCHAR(128) NOT NULL,
    RootSchema NVARCHAR(128) NOT NULL,
    RootObject NVARCHAR(128) NOT NULL,
    RootObjectType NVARCHAR(60) NOT NULL,
    DependentServer NVARCHAR(128) NOT NULL DEFAULT @@SERVERNAME,
    DependentDatabase NVARCHAR(128) NOT NULL,
    DependentSchema NVARCHAR(128) NOT NULL,
    DependentObject NVARCHAR(128) NOT NULL,
    DependentObjectType NVARCHAR(60) NOT NULL,
    LineagePath NVARCHAR(MAX), -- Full dependency chain
    LineageLevel INT, -- How many hops from root
    LineageDirection NVARCHAR(20), -- 'Upstream' or 'Downstream'
    CaptureDate DATETIME DEFAULT GETDATE()
);

CREATE INDEX IX_DependencyLineage_Root ON Utility.LineageObjectExtendedDependency(RootServer, RootDatabase, RootSchema, RootObject);
