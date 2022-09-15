CREATE TABLE [dbo].[HypotheticalIndex]
(
[HypotheticalIndexId] [int] NOT NULL,
[HypotheticalIndexValue] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[HypotheticalIndex] ADD CONSTRAINT [PK_HypotheticalIndex] PRIMARY KEY CLUSTERED ([HypotheticalIndexId]) ON [PRIMARY]
GO
