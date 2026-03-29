/* 
This table can be fed by a Dynamic merge metadata store.
*/

IF OBJECT_ID(N'Utility.LNG_DynamicMerge', N'U') IS NULL

BEGIN

Create table Utility.LNG_DynamicMerge
(
  SourceServerName        varchar(255)
, SourceDatabaseName      varchar(255)
, SourceSchemaName        varchar(255)
, SourceObjectName        varchar(255)
, SourceObjectType        varchar(255)
, ProcessServerName       varchar(255)
, ProcessDatabaseName     varchar(255)
, ProcessSchemaName       varchar(255)
, ProcessObjectName       varchar(255)
, ProcessObjectType       varchar(255)
, TargetServerName        varchar(255)
, TargetDatabaseName      varchar(255)
, TargetSchemaName        varchar(255)
, TargetObjectName        varchar(255)
, TargetObjectType        varchar(255)
)

END