CREATE TABLE [dbo].[UnencryptedData]
(
[UnencryptedDataId] [int] NOT NULL,
[Password] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PasswordIsEncrypted] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PasswordSalt] [varchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LastPasswordChangedDate] [date] NULL,
[PasswordConfigurationSettings] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PasswordComplexityPattern] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PasswordExpirationDate] [date] NULL,
[IsPasswordChangedFlag] [bit] NULL,
[LastPasswordFailedDate] [date] NULL,
[MaxPasswordCharacters] [int] NULL,
[MinPasswordLength] [int] NULL,
[PasswordSpecialCharacterRequirement] [bit] NULL,
[PasswordHistoryCount] [int] NULL,
[CreditCardId] [int] NULL,
[CreditCardNumber] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CreditCardApprovalCode] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CCN] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CreditCardToken] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SSN] [char] (9) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SocialSecurityNumber] [nchar] (11) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PassportNumber] [int] NULL,
[DLL] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DriverLicenseNumber] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LicenseCount] [bigint] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UnencryptedData] ADD CONSTRAINT [PK_UnencryptedData] PRIMARY KEY CLUSTERED  ([UnencryptedDataId]) ON [PRIMARY]
GO
