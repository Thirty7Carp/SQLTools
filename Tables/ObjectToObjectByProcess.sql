create TABLE [dbo].[ObjectToObjectByProcess](

	[SourceDatabaseName] [varchar](255) NULL,
	[SourceSchemaName] [varchar](255) NULL,
	[SourceObjectID] [bigint] NOT NULL,
	[SourceObjectType] [varchar](255) NULL,
	[SourceObjectName] [varchar](255) NULL,
	[ProcessDatabaseName] [varchar](255) NULL,
	[ProcessSchemaName] [varchar](255) NULL,
	[ProcessObjectID] [bigint] NOT NULL,
	[ProcessObjectName] [varchar](255) NULL,
	[ProcessObjectType] [varchar](255) NULL,
	[TargetDatabaseName] [varchar](255) NULL,
	[TargetSchemaName] [varchar](255) NULL,
	[TargetObjectID] [bigint] NOT NULL,
	[TargetObjectName] [varchar](255) NULL,
	[TargetObjectType] [varchar](255) NULL,
	[WH_ObjectToObjectByProcessID] [bigint] IDENTITY(1,1) NOT NULL,
	[WH_CreatedDatetime] [datetime] NOT NULL,
	[WH_UpdatedDatetime] [datetime] NOT NULL,
	[WH_IsCurrent] [bit] NOT NULL,
	[WH_EffectiveStartDatetime] [datetime] NOT NULL,
	[WH_EffectiveEndDatetime] [datetime] NULL,
	[WH_HashValue] [varbinary](8000) NULL,
PRIMARY KEY CLUSTERED 
(
	[WH_ObjectToObjectByProcessID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[ObjectToObjectByProcess] ADD  DEFAULT (getutcdate()) FOR [WH_CreatedDatetime]
GO

ALTER TABLE [dbo].[ObjectToObjectByProcess] ADD  DEFAULT (getutcdate()) FOR [WH_UpdatedDatetime]
GO

ALTER TABLE [dbo].[ObjectToObjectByProcess] ADD  DEFAULT ((1)) FOR [WH_IsCurrent]
GO

ALTER TABLE [dbo].[ObjectToObjectByProcess] ADD  DEFAULT (getutcdate()) FOR [WH_EffectiveStartDatetime]
GO


