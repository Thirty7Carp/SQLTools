USE [Meta]
GO

/****** Object:  Table [dbo].[ObjectAll]    Script Date: 22/01/2026 6:41:12 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ObjectAll](
	[DatabaseName] [nvarchar](128) NULL,
	[SchemaName] [nvarchar](128) NULL,
	[ObjectID] [int] NULL,
	[ObjectName] [nvarchar](256) NULL,
	[ObjectType] [nvarchar](60) NULL
) ON [PRIMARY]
GO
