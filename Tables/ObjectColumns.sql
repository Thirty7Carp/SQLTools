USE [Meta]
GO

/****** Object:  Table [dbo].[ObjectColumns]    Script Date: 22/01/2026 6:42:30 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ObjectColumns](
	[DatabaseName] [varchar](128) NULL,
	[TableName] [varchar](128) NULL,
	[ColumnName] [varchar](128) NULL,
	[ObjectID] [int] NULL
) ON [PRIMARY]
GO

