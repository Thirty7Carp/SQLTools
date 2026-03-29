IF OBJECT_ID(N'Utility.LNG_ObjectExpressionDependency', N'U') IS NULL

BEGIN

CREATE TABLE Utility.LNG_ObjectExpressionDependency (
    ExpressionDependencyID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ReferencingObjectID INT NOT NULL,
    ReferencingServer NVARCHAR(128) NOT NULL,
    ReferencingDatabase NVARCHAR(128) NOT NULL,
    ReferencingSchema NVARCHAR(128) NOT NULL,
    ReferencingObject NVARCHAR(128) NOT NULL,
    ReferencingObjectType NVARCHAR(60) NOT NULL,
    referenced_id INT NULL,
    referenced_server_name NVARCHAR(128) NOT NULL,
    referenced_database_name NVARCHAR(128) NOT NULL,
    referenced_schema_name NVARCHAR(128) NOT NULL,
    referenced_entity_name NVARCHAR(128) NOT NULL,
    ReferencedObjectType NVARCHAR(60) NULL,
    is_ambiguous BIT NOT NULL,
    CaptureDate DATETIME DEFAULT GETDATE()
)

END