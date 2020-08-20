SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[SelectEverything6]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @DeleteCount INT;

    SELECT @DeleteCount = COUNT(*) FROM dbo.NewspaperReader

	SELECT @DeleteCount

END;
GO
