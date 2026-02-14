

create TABLE [dbo].[ObjectDefinitions](
	[DatabaseName] [nvarchar](128) NULL,
	[SchemaName] [nvarchar](128) NULL,
	[ObjectID] [int] NULL,
	[ObjectName] [nvarchar](256) NULL,
	[ObjectType] [nvarchar](60) NULL,
	[ObjectDefinition] [nvarchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO


