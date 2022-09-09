CREATE TABLE [dbo].[FalsePositiveStatus]
(
[FalsePositiveStatusId] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[FalsePositiveStatus] ADD CONSTRAINT [PK_FalsePositiveStatus] PRIMARY KEY CLUSTERED ([FalsePositiveStatusId]) ON [PRIMARY]
GO
