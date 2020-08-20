CREATE TABLE [dbo].[IDPrimaryKeyColumnName]
(
[ID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[IDPrimaryKeyColumnName] ADD CONSTRAINT [PK_IDPrimaryKeyColumnName] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
