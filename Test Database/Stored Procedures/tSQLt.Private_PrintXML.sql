SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [tSQLt].[Private_PrintXML]
    @Message XML
AS 
BEGIN
    SELECT @Message FOR XML PATH('');--Required together with ":XML ON" sqlcmd statement to allow more than 1mb to be returned
    RETURN 0;
END;
GO
