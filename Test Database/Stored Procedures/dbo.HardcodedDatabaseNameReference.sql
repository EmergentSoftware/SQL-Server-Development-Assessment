SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[HardcodedDatabaseNameReference]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        WideId
       ,Column1
       ,Column2
       ,Column3
       ,Column4
       ,Column5
       ,Column6
       ,Column7
       ,Column8
       ,Column9
       ,Column10
       ,Column11
       ,Column12
       ,Column13
       ,Column14
       ,Column15
       ,Column16
       ,Column17
       ,Column18
       ,Column19
       ,Column20
    FROM
        spDevelop.dbo.Wide;
END;
GO
