SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [tSQLt].[Private_RemoveSchemaBinding]
  @object_id INT
AS
BEGIN
  DECLARE @cmd NVARCHAR(MAX);
  SELECT @cmd = tSQLt.[Private]::GetAlterStatementWithoutSchemaBinding(SM.definition)
    FROM sys.sql_modules AS SM
   WHERE SM.object_id = @object_id;
   EXEC(@cmd);
END;
GO
