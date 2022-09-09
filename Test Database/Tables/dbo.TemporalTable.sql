CREATE TABLE [dbo].[TemporalTable_history]
(
[TemporalTableId] [int] NOT NULL,
[SomeTemporalValue] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RowValidFromTime] [datetime2] NOT NULL,
[RowValidToTime] [datetime2] NOT NULL
) ON [PRIMARY]
GO
CREATE CLUSTERED INDEX [ix_TemporalTable_history] ON [dbo].[TemporalTable_history] ([RowValidToTime], [RowValidFromTime]) ON [PRIMARY]
GO
CREATE TABLE [dbo].[TemporalTable]
(
[TemporalTableId] [int] NOT NULL IDENTITY(1, 1),
[SomeTemporalValue] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RowValidFromTime] [datetime2] GENERATED ALWAYS AS ROW START NOT NULL CONSTRAINT [Account_AuditFromUtc_Default] DEFAULT (sysutcdatetime()),
[RowValidToTime] [datetime2] GENERATED ALWAYS AS ROW END NOT NULL CONSTRAINT [Account_AuditToUtc_Default] DEFAULT ('9999-12-31 23:59:59.9999999'),
PERIOD FOR SYSTEM_TIME (RowValidFromTime, RowValidToTime),
CONSTRAINT [DBO_TemporalTable_TemporalTableId] PRIMARY KEY CLUSTERED ([TemporalTableId]) ON [PRIMARY]
) ON [PRIMARY]
WITH
(
SYSTEM_VERSIONING = ON (HISTORY_TABLE = [dbo].[TemporalTable_history])
)
GO
