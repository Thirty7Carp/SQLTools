IF OBJECT_ID(N'Utility.LNG_ObjectExtendedDependencyLimit', N'U') IS NULL

BEGIN

CREATE TABLE Utility.LNG_ObjectExtendedDependencyLimit (
    LimitID        BIGINT IDENTITY(1,1) PRIMARY KEY,
    RootServer     NVARCHAR(128) NOT NULL,
    RootDatabase   NVARCHAR(128) NOT NULL,
    RootSchema     NVARCHAR(128) NOT NULL,
    RootObject     NVARCHAR(128) NOT NULL,
    LineageDirection NVARCHAR(20) NOT NULL,
    MaxLevel       INT NOT NULL,
    CaptureDate    DATETIME DEFAULT GETDATE()
)

END