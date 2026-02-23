declare @SourceServer varchar(max) = (select @@SERVERNAME)
declare @TZOffsetMinutes int = 480

select
SourceServer  = @SourceServer
, SourceDatabase = SourceDatabaseName
, SourceSchema = SourceSchemaName
, SourceObject = SourceObjectName
, SourceType = SourceObjectType
, TargetServer = @SourceServer
, TatargetDatabase = ProcessDatabaseName
, TargetSchema = ProcessSchemaName
, TargetObject = ProcessObjectName
, TargetType = ProcessObjectType
, DependencyType = 'Direct'
, [IsSchemabound] = 0
, [Level] = 1
, CaptureDate = dateadd(n, @TZOffsetMinutes, getutcdate())
from
	SQLTools.Utility.DynamicMerge

UNION ALL


select
SourceServer  = ProcessServerName
, SourceDatabase = ProcessDatabaseName
, SourceSchema = ProcessSchemaName
, SourceObject = ProcessObjectName
, SourceType = ProcessObjectType
, TargetServer = @SourceServer
, TatargetDatabase = TargetDatabaseName
, TargetSchema = TargetSchemaName
, TargetObject = TargetObjectName
, TargetType = TargetObjectType
, DependencyType = 'Direct'
, [IsSchemabound] = 0
, [Level] = 1
, CaptureDate = dateadd(n, @TZOffsetMinutes, getutcdate())
from
	SQLTools.Utility.DynamicMerge

