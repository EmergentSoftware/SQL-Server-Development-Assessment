SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [tSQLt].[Private_RunNew]
  @TestResultFormatter NVARCHAR(MAX)
AS
BEGIN
  EXEC tSQLt.Private_RunCursor @TestResultFormatter = @TestResultFormatter, @GetCursorCallback = 'tSQLt.Private_GetCursorForRunNew';
END;
GO
