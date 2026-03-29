
IF OBJECT_ID(N'Utility.LNG_ObjectDefinitions', N'U') IS NULL

BEGIN

create TABLE [Utility].[LNG_ObjectDefinitions](
	[ObjectID] [int] NULL,
	[ServerName] varchar(255) NULL,
	[DatabaseName] [nvarchar](128) NULL,
	[SchemaName] [nvarchar](128) NULL,
	[ObjectName] [nvarchar](256) NULL,
	[ObjectType] [nvarchar](60) NULL,
	[ObjectDefinition] [nvarchar](max) NULL
) 

END
