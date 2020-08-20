CREATE TABLE [dbo].[ColumnSameAsTable]
(
[ColumnSameAsTable] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ColumnSameAsTable] ADD CONSTRAINT [PK_ColumnSameAsTable] PRIMARY KEY CLUSTERED  ([ColumnSameAsTable]) ON [PRIMARY]
GO
