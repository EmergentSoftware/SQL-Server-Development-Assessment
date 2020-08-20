CREATE TABLE [dbo].[Users]
(
[Id] [int] NOT NULL IDENTITY(1, 1),
[First] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Last] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Users] ADD CONSTRAINT [PK_Users] PRIMARY KEY CLUSTERED  ([Id]) ON [PRIMARY]
GO
