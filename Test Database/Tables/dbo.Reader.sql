CREATE TABLE [dbo].[Reader]
(
[ReaderId] [int] NOT NULL,
[Name] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Reader] ADD CONSTRAINT [PK_Reader] PRIMARY KEY CLUSTERED  ([ReaderId]) ON [PRIMARY]
GO
