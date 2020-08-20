SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[MulitStatement] (@ParameterName1 AS INT, @ParameterName2 AS VARCHAR(50))
RETURNS @VariableName TABLE (ColumnName1 INT NOT NULL, ColumnName2 VARCHAR(50) NOT NULL)
AS
BEGIN
    -- Return the result of the function
    INSERT INTO
        @VariableName (ColumnName1, ColumnName2)
    SELECT ColumnName1 = @ParameterName1, ColumnName2 = @ParameterName2;
    RETURN;
END;
GO
