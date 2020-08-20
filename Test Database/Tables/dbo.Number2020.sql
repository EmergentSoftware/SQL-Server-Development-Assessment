CREATE TABLE [dbo].[Number2020]
(
[Number2020Id] [int] NOT NULL,
[TableNameContainsNumbers] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Number2020] ADD CONSTRAINT [PK_Number2020] PRIMARY KEY CLUSTERED  ([Number2020Id]) ON [PRIMARY]
GO
