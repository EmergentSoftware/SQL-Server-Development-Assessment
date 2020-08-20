CREATE TABLE [dbo].[Newspaper]
(
[NewspaperId] [int] NOT NULL,
[Name] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Newspaper] ADD CONSTRAINT [PK_Newspaper] PRIMARY KEY CLUSTERED  ([NewspaperId]) ON [PRIMARY]
GO
