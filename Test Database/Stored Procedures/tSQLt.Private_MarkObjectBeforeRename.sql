SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [tSQLt].[Private_MarkObjectBeforeRename]
    @SchemaName NVARCHAR(MAX), 
    @OriginalName NVARCHAR(MAX)
AS
BEGIN
  INSERT INTO tSQLt.Private_RenamedObjectLog (ObjectId, OriginalName) 
  VALUES (OBJECT_ID(@SchemaName + '.' + @OriginalName), @OriginalName);
END;
GO
