SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*******************************************************************************************/
/*******************************************************************************************/
/*******************************************************************************************/
CREATE FUNCTION [tSQLt].[Private_GetCleanSchemaName](@SchemaName NVARCHAR(MAX), @ObjectName NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    RETURN (SELECT SCHEMA_NAME(schema_id) 
              FROM sys.objects 
             WHERE object_id = CASE WHEN ISNULL(@SchemaName,'') in ('','[]')
                                    THEN OBJECT_ID(@ObjectName)
                                    ELSE OBJECT_ID(@SchemaName + '.' + @ObjectName)
                                END);
END;
GO
