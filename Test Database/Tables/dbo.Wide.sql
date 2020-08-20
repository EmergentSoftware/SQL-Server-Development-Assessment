CREATE TABLE [dbo].[Wide]
(
[WideId] [int] NOT NULL,
[Column1] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column2] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column3] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column4] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column5] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column6] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column7] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column8] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column9] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column10] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column11] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column12] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column13] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column14] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column15] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column16] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column17] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column18] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column19] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Column20] [nchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Wide] ADD CONSTRAINT [PK_Wide] PRIMARY KEY CLUSTERED  ([WideId]) ON [PRIMARY]
GO
