CREATE TABLE [dbo].[ColumnCollationDifferent]
(
[ColumnCollationDifferentId] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DifferentCollationThanDatabase] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ColumnCollationDifferent] ADD CONSTRAINT [PK_ColumnCollationDifferent] PRIMARY KEY CLUSTERED ([ColumnCollationDifferentId]) ON [PRIMARY]
GO
