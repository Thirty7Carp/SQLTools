IF OBJECT_ID(N'Utility.LNG_ObjectExclusions', N'U') IS NULL

BEGIN


CREATE TABLE Utility.LNG_ObjectExclusions (
    ExclusionID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128) NULL,  -- NULL means all servers
    DatabaseName NVARCHAR(128) NULL,  -- NULL means all databases
    SchemaName NVARCHAR(128) NULL,  -- NULL means all schemas
    ObjectName NVARCHAR(128) NOT NULL,  -- Object name (supports wildcards with LIKE)
    ExclusionReason NVARCHAR(500) NULL,  -- Why this is excluded
    CreatedDate DATETIME DEFAULT GETDATE(),
    CreatedBy NVARCHAR(128) DEFAULT SUSER_SNAME(),
    IsActive BIT DEFAULT 1,  -- Allow disabling without deleting
    CONSTRAINT UQ_LNG_LineageExclusions UNIQUE (ServerName, DatabaseName, SchemaName, ObjectName)
)

END