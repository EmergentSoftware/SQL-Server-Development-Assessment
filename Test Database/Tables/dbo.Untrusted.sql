CREATE TABLE [dbo].[Untrusted]
(
[UntrustedId] [int] NULL,
[Reader] [int] NULL,
[RegularPrice] [decimal] (18, 4) NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Untrusted] WITH NOCHECK ADD CONSTRAINT [Untrusted_RegularPrice_Maximum] CHECK (([RegularPrice]<(1000)))
GO
ALTER TABLE [dbo].[Untrusted] WITH NOCHECK ADD CONSTRAINT [Untrusted_RegularPrice_Minimum] CHECK (([RegularPrice]>(0)))
GO
ALTER TABLE [dbo].[Untrusted] NOCHECK CONSTRAINT [Untrusted_RegularPrice_Maximum]
GO
ALTER TABLE [dbo].[Untrusted] WITH NOCHECK ADD CONSTRAINT [Untrusted_Reader] FOREIGN KEY ([UntrustedId]) REFERENCES [dbo].[Reader] ([ReaderId])
GO
ALTER TABLE [dbo].[Untrusted] NOCHECK CONSTRAINT [Untrusted_Reader]
GO
