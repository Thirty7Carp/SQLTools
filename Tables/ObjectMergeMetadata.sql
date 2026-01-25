USE [Meta]
GO

/****** Object:  Table [dbo].[ObjectMergeMetadata]    Script Date: 22/01/2026 6:49:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create TABLE [dbo].[ObjectMergeMetadata](
	[SourceDatabaseName] [varchar](255) NULL,
	[SourceSchemaName] [varchar](255) NULL,
	[SourceObjectName] [varchar](255) NULL,
	[TargetDatabaseName] [varchar](255) NULL,
	[TargetSchemaName] [varchar](255) NULL,
	[TargetObjectName] [varchar](255) NULL,
	[LoadType] [varchar](50) NULL,
	[SCDType] [varchar](50) NULL,
	[MergeFields] [varchar](max) NULL,
	[ValueFields] [varchar](max) NULL,
	[IgnoreFields] [varchar](max) NULL,
	[MetadataFields] [varchar](max) NULL,
	[WH_ObjectMergeMetadataID] [bigint] IDENTITY(1,1) NOT NULL,
	[WH_CreatedDatetime] [datetime] NOT NULL,
	[WH_UpdatedDatetime] [datetime] NOT NULL,
	[WH_IsCurrent] [bit] NOT NULL,
	[WH_EffectiveStartDatetime] [datetime] NOT NULL,
	[WH_EffectiveEndDatetime] [datetime] NULL,
	[WH_HashValue] [varbinary](8000) NULL,
PRIMARY KEY CLUSTERED 
(
	[WH_ObjectMergeMetadataID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [dbo].[ObjectMergeMetadata] ADD  DEFAULT (getutcdate()) FOR [WH_CreatedDatetime]
GO

ALTER TABLE [dbo].[ObjectMergeMetadata] ADD  DEFAULT (getutcdate()) FOR [WH_UpdatedDatetime]
GO

ALTER TABLE [dbo].[ObjectMergeMetadata] ADD  DEFAULT ((1)) FOR [WH_IsCurrent]
GO

ALTER TABLE [dbo].[ObjectMergeMetadata] ADD  DEFAULT (getutcdate()) FOR [WH_EffectiveStartDatetime]
GO


