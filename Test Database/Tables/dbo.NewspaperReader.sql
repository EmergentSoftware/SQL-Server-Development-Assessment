CREATE TABLE [dbo].[NewspaperReader]
(
[NewspaperReaderId] [int] NOT NULL,
[NewspaperId] [int] NOT NULL,
[ReaderId] [int] NOT NULL,
[SubscriptionEndDate] [date] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[NewspaperReader] ADD CONSTRAINT [PK_NewspaperReader] PRIMARY KEY CLUSTERED  ([NewspaperReaderId]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[NewspaperReader] ADD CONSTRAINT [FK_NewspaperReader_Newspaper] FOREIGN KEY ([NewspaperId]) REFERENCES [dbo].[Newspaper] ([NewspaperId])
GO
ALTER TABLE [dbo].[NewspaperReader] ADD CONSTRAINT [FK_NewspaperReader_Reader] FOREIGN KEY ([ReaderId]) REFERENCES [dbo].[Reader] ([ReaderId])
GO
