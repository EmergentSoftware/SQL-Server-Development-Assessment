SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [tSQLt].[RemoveObjectIfExists] 
    @ObjectName NVARCHAR(MAX),
    @NewName NVARCHAR(MAX) = NULL OUTPUT
AS
BEGIN
  EXEC tSQLt.RemoveObject @ObjectName = @ObjectName, @NewName = @NewName OUT, @IfExists = 1;
END;
GO
