

/****** Object:  Table [dbo].[ObjectFullLineage]    Script Date: 22/01/2026 6:43:33 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create TABLE [dbo].[ObjectFullLineage](
	[RootDatabaseName] [varchar](255) NULL,
	[RootSchemaName] [varchar](255) NULL,
	[RootObjectID] [bigint] NOT NULL,
	[RootObjectName] [varchar](255) NULL,
	[RootObjectType] [varchar](255) NULL,
	[SourceDatabaseName] [varchar](255) NULL,
	[SourceSchemaName] [varchar](255) NULL,
	[SourceObjectID] [bigint] NOT NULL,
	[SourceObjectName] [varchar](255) NULL,
	[SourceObjectType] [varchar](255) NULL,
	[TargetDatabaseName] [varchar](255) NULL,
	[TargetSchemaName] [varchar](255) NULL,
	[TargetObjectID] [bigint] NOT NULL,
	[TargetObjectName] [varchar](255) NULL,
	[TargetObjectType] [varchar](255) NULL,
	[FullPathID] [varchar](255) NOT NULL,
	[FullPathName] [varchar](255) NOT NULL,
	[WH_ObjectFullLineageID] [bigint] IDENTITY(1,1) NOT NULL,
	[WH_CreatedDatetime] [datetime] NOT NULL,
	[WH_UpdatedDatetime] [datetime] NOT NULL,
	[WH_IsCurrent] [bit] NOT NULL,
	[WH_EffectiveStartDatetime] [datetime] NOT NULL,
	[WH_EffectiveEndDatetime] [datetime] NULL,
	[WH_HashValue] [varbinary](8000) NULL,
PRIMARY KEY CLUSTERED 
(
	[WH_ObjectFullLineageID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[ObjectFullLineage] ADD  DEFAULT (getutcdate()) FOR [WH_CreatedDatetime]
GO

ALTER TABLE [dbo].[ObjectFullLineage] ADD  DEFAULT (getutcdate()) FOR [WH_UpdatedDatetime]
GO

ALTER TABLE [dbo].[ObjectFullLineage] ADD  DEFAULT ((1)) FOR [WH_IsCurrent]
GO

ALTER TABLE [dbo].[ObjectFullLineage] ADD  DEFAULT (getutcdate()) FOR [WH_EffectiveStartDatetime]
GO


