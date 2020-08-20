CREATE TABLE [dbo].[Procedure]
(
[ProcedureId] [int] NOT NULL,
[ReservedTableName] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Procedure] ADD CONSTRAINT [PK_Procedure] PRIMARY KEY CLUSTERED  ([ProcedureId]) ON [PRIMARY]
GO
