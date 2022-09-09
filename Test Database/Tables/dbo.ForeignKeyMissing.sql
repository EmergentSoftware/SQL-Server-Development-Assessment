CREATE TABLE [dbo].[ForeignKeyMissing]
(
[ForeignKeyMissingId] [int] NOT NULL IDENTITY(1, 1),
[SomeKindOfId] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ForeignKeyMissing] ADD CONSTRAINT [PK_ForeignKeyMissing] PRIMARY KEY CLUSTERED ([ForeignKeyMissingId]) ON [PRIMARY]
GO
