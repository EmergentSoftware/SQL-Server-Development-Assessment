SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[SelectEverything7]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        NewspaperReaderId
       ,NewspaperId
       ,ReaderId
       ,SubscriptionEndDate
       ,Math = 1 * 4
    FROM
        dbo.NewspaperReader;

END;
GO
