SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [tSQLt].[RunWithNullResults]
    @TestName NVARCHAR(MAX) = NULL
AS
BEGIN
  EXEC tSQLt.Run @TestName = @TestName, @TestResultFormatter = 'tSQLt.NullTestResultFormatter';
END;
GO
