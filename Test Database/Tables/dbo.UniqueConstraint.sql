CREATE TABLE [dbo].[UniqueConstraint]
(
[ColumnName] [char] (11) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UniqueConstraint] ADD CONSTRAINT [AK_UniqueConstraint_ColumnName] UNIQUE NONCLUSTERED  ([ColumnName]) ON [PRIMARY]
GO
