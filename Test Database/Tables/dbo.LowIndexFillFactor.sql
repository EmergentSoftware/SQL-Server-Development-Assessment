CREATE TABLE [dbo].[LowIndexFillFactor]
(
[LowIndexFillFactorId] [int] NOT NULL,
[Below80PercentFillFactor] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Above80PercentFillFactor] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LowIndexFillFactor] ADD CONSTRAINT [PK_LowIndexFillFactor] PRIMARY KEY CLUSTERED ([LowIndexFillFactorId]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [LowIndexFillFactor_Above80PercentFillFactor] ON [dbo].[LowIndexFillFactor] ([Above80PercentFillFactor]) WITH (FILLFACTOR=85) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [LowIndexFillFactor_98PercentFillFactor] ON [dbo].[LowIndexFillFactor] ([Above80PercentFillFactor]) INCLUDE ([Below80PercentFillFactor]) WITH (FILLFACTOR=98) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [LowIndexFillFactor_Below80PercentFillFactor] ON [dbo].[LowIndexFillFactor] ([Below80PercentFillFactor]) WITH (FILLFACTOR=75) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [LowIndexFillFactor_2PercentFillFactor] ON [dbo].[LowIndexFillFactor] ([Below80PercentFillFactor], [Above80PercentFillFactor]) INCLUDE ([LowIndexFillFactorId]) WITH (FILLFACTOR=2) ON [PRIMARY]
GO
