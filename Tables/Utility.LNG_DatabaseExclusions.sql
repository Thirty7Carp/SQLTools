drop table if exists Utility.LNG_DatabaseExclusions

CREATE TABLE Utility.LNG_DatabaseExclusions (
    ExclusionID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128) NULL,  -- NULL means all servers
    DatabaseName NVARCHAR(128) NOT NULL,  -- Database name (supports wildcards with LIKE)
    ExclusionReason NVARCHAR(500) NULL, 
    CreatedDate DATETIME DEFAULT GETDATE(),
    CreatedBy NVARCHAR(128) DEFAULT SUSER_SNAME(),
    IsActive BIT DEFAULT 1,  -- Allow disabling without deleting
    CONSTRAINT UQ_LNG_DatabaseExclusions UNIQUE (ServerName, DatabaseName)
);