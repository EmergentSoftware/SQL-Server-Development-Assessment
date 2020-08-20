CREATE TABLE [dbo].[tblPhone]
(
[ID] [uniqueidentifier] NOT NULL,
[Phone Number] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[fld_PrefixColumn] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[c_PrefixColumn] [bit] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[tblPhone] ADD CONSTRAINT [PK_ID] PRIMARY KEY NONCLUSTERED  ([ID]) ON [PRIMARY]
GO
