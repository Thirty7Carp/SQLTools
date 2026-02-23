
create TABLE [Utility].[LineageObjectDefinitions](
	[ObjectID] [int] NULL,
	[ServerName] varchar(255) NULL,
	[DatabaseName] [nvarchar](128) NULL,
	[SchemaName] [nvarchar](128) NULL,
	[ObjectName] [nvarchar](256) NULL,
	[ObjectType] [nvarchar](60) NULL,
	[ObjectDefinition] [nvarchar](max) NULL
) 
