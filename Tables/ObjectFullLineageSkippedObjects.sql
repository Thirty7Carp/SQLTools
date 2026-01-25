USE [Meta]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create TABLE [dbo].[ObjectFullLineageSkippedObjects](
	[RootDatabaseName] [varchar](255) NULL,
	[RootSchemaName] [varchar](255) NULL,
	[RootObjectID] [bigint] NOT NULL,
	[RootObjectName] [varchar](255) NULL,
	[RootObjectType] [varchar](255) NULL,
	[RootObjectLineageStepReached] [int] NOT NULL,
	[WH_ObjectFullLineageSkippedObjectsID] [bigint] IDENTITY(1,1) NOT NULL,
	[WH_CreatedDatetime] [datetime] NOT NULL,
	[WH_UpdatedDatetime] [datetime] NOT NULL,
	[WH_IsCurrent] [bit] NOT NULL,
	[WH_EffectiveStartDatetime] [datetime] NOT NULL,
	[WH_EffectiveEndDatetime] [datetime] NULL,
	[WH_HashValue] [varbinary](8000) NULL,
PRIMARY KEY CLUSTERED 
(
	[WH_ObjectFullLineageSkippedObjectsID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[ObjectFullLineageSkippedObjects] ADD  DEFAULT (getutcdate()) FOR [WH_CreatedDatetime]
GO

ALTER TABLE [dbo].[ObjectFullLineageSkippedObjects] ADD  DEFAULT (getutcdate()) FOR [WH_UpdatedDatetime]
GO

ALTER TABLE [dbo].[ObjectFullLineageSkippedObjects] ADD  DEFAULT ((1)) FOR [WH_IsCurrent]
GO

ALTER TABLE [dbo].[ObjectFullLineageSkippedObjects] ADD  DEFAULT (getutcdate()) FOR [WH_EffectiveStartDatetime]
GO


