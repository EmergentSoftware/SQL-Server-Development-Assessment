SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [dbo].[NonInlineable] (@Param1 INT)
RETURNS DATETIME2
AS
BEGIN
    -- Declare the return variable here
    DECLARE @ResultVar DATETIME2(7);

    -- Add the T-SQL statements to compute the return value here
    SET @ResultVar = GETDATE();

    -- Return the result of the function
    RETURN @ResultVar;

END;
GO
