drop table if exists Utility.LNG_DynamicMerge

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
, IsActive                bit             -- Enable or disable a merge without deleting the record
, SCDType                 varchar(255)    -- Slowly Changing Dimension type
, ColumnJoin              varchar(max)    -- Columns to match on
, ColumnValueDiff         varchar(max)    -- Columns to look for a difference in values
, ColumnIgnore            varchar(max)    -- Columns to ignore for the update
, DeleteIfNotMatchedBySource bit          -- Bit value to allow partial loads
)