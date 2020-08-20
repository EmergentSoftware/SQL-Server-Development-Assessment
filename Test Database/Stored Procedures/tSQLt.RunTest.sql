SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [tSQLt].[RunTest]
   @TestName NVARCHAR(MAX)
AS
BEGIN
  RAISERROR('tSQLt.RunTest has been retired. Please use tSQLt.Run instead.', 16, 10);
END;
GO
