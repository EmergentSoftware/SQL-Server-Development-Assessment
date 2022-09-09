CREATE TABLE [dbo].[NamingForeignKeyRelationship]
(
[NamingForeignKeyRelationshipId] [int] NOT NULL IDENTITY(1, 1),
[GenericOrClassWordId] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[NamingForeignKeyRelationship] ADD CONSTRAINT [PK_NamingForeignKeyRelationship] PRIMARY KEY CLUSTERED ([NamingForeignKeyRelationshipId]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[NamingForeignKeyRelationship] ADD CONSTRAINT [FK_NamingForeignKeyRelationship_GenericOrClassWord] FOREIGN KEY ([GenericOrClassWordId]) REFERENCES [dbo].[GenericOrClassWord] ([GenericOrClassWordId])
GO
