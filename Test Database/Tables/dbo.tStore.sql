CREATE TABLE [dbo].[tStore]
(
[tStoreId] [int] NOT NULL,
[DiscountAmount] [money] NULL,
[Col_PrefixColumn] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[u_PrefixColumn] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[tStore] ADD CONSTRAINT [PK_tStore] PRIMARY KEY CLUSTERED  ([tStoreId]) ON [PRIMARY]
GO
