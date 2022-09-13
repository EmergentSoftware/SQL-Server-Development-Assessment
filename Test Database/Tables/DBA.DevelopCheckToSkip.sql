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
ALTER TABLE [DBA].[DevelopCheckToSkip] ADD CONSTRAINT [DevelopCheckToSkip_DevelopCheckToSkipId] PRIMARY KEY CLUSTERED ([DevelopCheckToSkipId]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [DevelopCheckToSkip_CheckId] ON [DBA].[DevelopCheckToSkip] ([CheckId]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [DevelopCheckToSkip_DatabaseName] ON [DBA].[DevelopCheckToSkip] ([DatabaseName]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [DevelopCheckToSkip_ObjectName] ON [DBA].[DevelopCheckToSkip] ([ObjectName]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [DevelopCheckToSkip_SchemaName] ON [DBA].[DevelopCheckToSkip] ([SchemaName]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [DevelopCheckToSkip_ServerName] ON [DBA].[DevelopCheckToSkip] ([ServerName]) ON [PRIMARY]
GO
