CREATE TABLE [dbo].[UniqueConstraint]
(
[SSN] [char] (11) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UniqueConstraint] ADD CONSTRAINT [AK_UniqueConstraint_SSN] UNIQUE NONCLUSTERED  ([SSN]) ON [PRIMARY]
GO
