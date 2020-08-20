SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE VIEW [dbo].[vHardcodedDatabaseNameReference]
AS
SELECT     Id, First, Last
FROM        spDevelop.dbo.Users
GO
