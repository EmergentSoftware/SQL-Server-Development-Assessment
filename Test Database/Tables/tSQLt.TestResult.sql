CREATE TABLE [tSQLt].[TestResult]
(
[Id] [int] NOT NULL IDENTITY(1, 1),
[Class] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[TestCase] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] AS ((quotename([Class])+'.')+quotename([TestCase])),
[TranName] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Result] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Msg] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TestStartTime] [datetime] NOT NULL CONSTRAINT [DF:TestResult(TestStartTime)] DEFAULT (getdate()),
[TestEndTime] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [tSQLt].[TestResult] ADD CONSTRAINT [PK__TestResu__3214EC079EBFD53D] PRIMARY KEY CLUSTERED  ([Id]) ON [PRIMARY]
GO
