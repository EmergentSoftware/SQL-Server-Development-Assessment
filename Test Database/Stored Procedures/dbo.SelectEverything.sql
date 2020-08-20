SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
--SET QUOTED_IDENTIFIER ON|OFF
--SET ANSI_NULLS ON|OFF
/**********************************************************************************************************************
** Author:      sa
** Created On:  8/9/2020
** Modified On: 8/9/2020
** Description: SELECT EVERYTHING
**********************************************************************************************************************/
CREATE   PROCEDURE [dbo].[SelectEverything]
AS
BEGIN
	SET NOCOUNT ON;
	
	SELECT * FROM dbo.NewspaperReader AS NR

END
GO
