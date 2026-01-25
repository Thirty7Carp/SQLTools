USE [Meta]
GO

/****** Object:  Table [dbo].[ObjectDefinitions]    Script Date: 22/01/2026 6:43:02 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create TABLE [dbo].[ObjectDefinitions](
	[DatabaseName] [nvarchar](128) NULL,
	[SchemaName] [nvarchar](128) NULL,
	[ObjectID] [int] NULL,
	[ObjectName] [nvarchar](256) NULL,
	[ObjectType] [nvarchar](60) NULL,
	[ObjectDefinition] [nvarchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO


