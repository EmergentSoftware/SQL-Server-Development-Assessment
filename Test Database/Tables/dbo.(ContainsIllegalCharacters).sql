CREATE TABLE [dbo].[(ContainsIllegalCharacters)]
(
[(ContainsIllegalCharacters)Id] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[(ContainsIllegalCharacters)] ADD CONSTRAINT [PK_(ContainsIllegalCharacters)] PRIMARY KEY CLUSTERED  ([(ContainsIllegalCharacters)Id]) ON [PRIMARY]
GO
