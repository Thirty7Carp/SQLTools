Drop table if exists Utility.LNG_ObjectList

-- Store all database objects across all databases
CREATE TABLE Utility.LNG_ObjectList (
    ObjectID BIGINT,
    ServerName NVARCHAR(128) NOT NULL DEFAULT @@SERVERNAME,
    DatabaseName NVARCHAR(128) NOT NULL,
    SchemaName NVARCHAR(128) NOT NULL,
    ObjectName NVARCHAR(128) NOT NULL,
    ObjectType NVARCHAR(60) NOT NULL,
    ObjectTypeName NVARCHAR(60) NOT NULL,
    CreateDate DATETIME,
    ModifyDate DATETIME,
    FullObjectName AS ServerName + '.' + DatabaseName + '.' + SchemaName + '.' + ObjectName,
    CaptureDate DATETIME DEFAULT GETDATE(),
    CONSTRAINT UQ_LNG_DatabaseObjects UNIQUE (ServerName, DatabaseName, SchemaName, ObjectName, ObjectType)
);
GO