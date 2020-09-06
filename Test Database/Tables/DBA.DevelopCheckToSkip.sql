CREATE TABLE [DBA].[DevelopCheckToSkip]
(
[DevelopCheckToSkipId] [int] NOT NULL IDENTITY(1, 1),
[ServerName] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DatabaseName] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SchemaName] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ObjectName] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CheckId] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [DBA].[DevelopCheckToSkip] ADD CONSTRAINT [DevelopCheckToSkip_DevelopCheckToSkipId] PRIMARY KEY CLUSTERED  ([DevelopCheckToSkipId]) ON [PRIMARY]
GO
