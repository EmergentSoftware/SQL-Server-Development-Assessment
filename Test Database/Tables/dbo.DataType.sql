CREATE TABLE [dbo].[DataType]
(
[DataTypeId] [int] NOT NULL,
[UnitPriceTotal] [money] NULL,
[UnitPrice] [smallmoney] NULL,
[ProductDescription] [text] COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ProductDescriptionInternational] [ntext] COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LineAmount] [float] NULL,
[LineTotal] [real] NULL,
[ProfileInformation] [sql_variant] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[DataType] ADD CONSTRAINT [PK_DataType] PRIMARY KEY CLUSTERED  ([DataTypeId]) ON [PRIMARY]
GO
