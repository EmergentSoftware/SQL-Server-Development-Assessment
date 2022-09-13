CREATE TABLE [dbo].[DisabledIndex]
(
[DisabledIndexId] [int] NOT NULL,
[SomeValue] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AnotherValue] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[DisabledIndex] ADD CONSTRAINT [PK_DisabledIndex] PRIMARY KEY CLUSTERED ([DisabledIndexId]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [DisabledIndex_AnotherValue] ON [dbo].[DisabledIndex] ([AnotherValue]) INCLUDE ([SomeValue]) ON [PRIMARY]
GO
ALTER INDEX [DisabledIndex_AnotherValue] ON [dbo].[DisabledIndex] DISABLE
GO
CREATE NONCLUSTERED INDEX [DisabledIndex_SomeValue] ON [dbo].[DisabledIndex] ([SomeValue]) ON [PRIMARY]
GO
ALTER INDEX [DisabledIndex_SomeValue] ON [dbo].[DisabledIndex] DISABLE
GO
