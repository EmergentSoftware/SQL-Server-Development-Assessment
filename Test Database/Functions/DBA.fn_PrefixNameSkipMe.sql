SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [DBA].[fn_PrefixNameSkipMe]
(
	@Param1 INT
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @ResultVar INT

	-- Add the T-SQL statements to compute the return value here
	SET @ResultVar = 1

	-- Return the result of the function
	RETURN @ResultVar

END
GO
