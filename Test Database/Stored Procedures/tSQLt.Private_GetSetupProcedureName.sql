SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [tSQLt].[Private_GetSetupProcedureName]
  @TestClassId INT = NULL,
  @SetupProcName NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SELECT @SetupProcName = tSQLt.Private_GetQuotedFullName(object_id)
      FROM sys.procedures
     WHERE schema_id = @TestClassId
       AND LOWER(name) = 'setup';
END;
GO
